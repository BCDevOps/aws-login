'use strict'

let fs = require("fs");
let path = require("path");
let AWS = require("aws-sdk");
let https = require('https');
var qs = require('querystring');

exports.handler = function (event, context, callback) {
  if (event.path == "/redirect" && event.httpMethod == "GET") {
    const kc_base_url = process.env.kc_base_url;
    const kc_realm = process.env.kc_realm;
    const response = {
      statusCode: 301,
      headers: {
        Location: 'https://' + kc_base_url + '/auth/realms/' + kc_realm + '/protocol/saml/clients/amazon-aws',
      }
    };

    callback(null, response)
  }

  else if (event.path == "/" && event.httpMethod == "POST") {
    const fileName = "index.html";

    let resolved = null;
    if (process.env.LAMBDA_TASK_ROOT) {
      resolved = path.resolve(process.env.LAMBDA_TASK_ROOT, fileName);
    } else {
      resolved = path.resolve(__dirname, fileName);
    }

    const data = fs.readFileSync(resolved, 'utf8');

    let samlResponse = event.body.replace('SAMLResponse=', '');
    const temp_rolearn = process.env.samlReadRole.split(",")[1];
    const serverless_saml_user_account_read_role = temp_rolearn.substr(temp_rolearn.lastIndexOf("/") + 1);

    let html = data.replace("##SAMLRESPONSE##", decodeURIComponent(samlResponse)).replace("##serverless_saml_user_account_read_role##", serverless_saml_user_account_read_role);

    var response = {
      statusCode: 200,
      headers: {
        'Content-Type': 'text/html; charset=utf-8',
        'Access-Control-Allow-Origin': '*',// Required for CORS support to work
        'Access-Control-Allow-Headers': '*',
        "Access-Control-Allow-Methods": "OPTIONS,POST,GET"
      },
      body: html
    }

    callback(null, response)
  }

  else if (event.path == "/accounttags" && event.httpMethod == "POST") {
    if (event.body) {

      let body = JSON.parse(event.body);

      let buff = Buffer.from(body.samlResponse, "base64");
      let decodedsamlResponse = buff.toString("utf-8");

      // check if azure ad idir user is logged in
      if (checkSAMLForAzureIDP(decodedsamlResponse)) {
        transferKeyCloakGroups(decodedsamlResponse)
      }

      let accounts = parseSAMLResponse(decodedsamlResponse);
      let saml_read_role = process.env.samlReadRole.split(",");
      let roleArn = saml_read_role[1];
      let sts = new AWS.STS();

      let params = {
        DurationSeconds: 900,
        RoleArn: roleArn,
        RoleSessionName: "AWSLoginAppOrgRead"
      };

      sts.assumeRole(params, function (err, data) {
        if (err) {
          console.log(err, err.stack);
          var response = {
            statusCode: 500,
            body: JSON.stringify(err)
          };

          callback(null, response);
        } else {
          let organizations = new AWS.Organizations({
            accessKeyId: data.Credentials.AccessKeyId,
            secretAccessKey: data.Credentials.SecretAccessKey,
            sessionToken: data.Credentials.SessionToken,
            region: "us-east-1"
          });

          var getTagsForAccounts = function getTagsForAccounts(accountData, orgClient) {
            return Promise.all(Object.keys(accountData).map(function (account) {
              return new Promise((resolve, reject) => {
                organizations.listTagsForResource({ ResourceId: account }, function (err, data) {
                  if (err) {
                    reject(err);
                  }
                  let accountTags = {};
                  accountTags.accountId = account;
                  accountTags.tags = data.Tags;
                  organizations.describeAccount({ AccountId: account }, function (e, d) {
                    if (e) {
                      console.log(e);
                      reject(e);
                    }

                    accountTags.accountName = d.Account.Name;
                    resolve(accountTags);
                  });
                });
              });
            }))
          };

          getTagsForAccounts(accounts, organizations)
            .then((values) => {
              let returnVal = {};
              for (const val of values) {
                returnVal[val.accountId] = val;
              }

              var response = {
                statusCode: 200,
                body: JSON.stringify(returnVal)
              };

              callback(null, response);
            });
        }

      });

    }
  }
  else if (event.path == "/consolelogin" && event.httpMethod == "POST") {

    if (event.body) {

      let body = JSON.parse(event.body);

      let principalArn = body.PrincipalArn;
      let roleArn = body.RoleArn;
      let samlResponse = body.SAMLAssertion;
      let duration = body.DurationSeconds;

      let sts = new AWS.STS();

      let params = {
        DurationSeconds: duration,
        PrincipalArn: principalArn,
        RoleArn: roleArn,
        SAMLAssertion: samlResponse
      };

      sts.assumeRoleWithSAML(params, function (err, data) {
        if (err) {
          console.log(err, err.stack);
        } else {

          let accessKeyId = data.Credentials.AccessKeyId;
          let secretKey = data.Credentials.SecretAccessKey;
          let sessionToken = data.Credentials.SessionToken;
          let issuer = data.Issuer;

          let st =
          {
            "sessionId": accessKeyId,
            "sessionKey": secretKey,
            "sessionToken": sessionToken
          }

          let sessionTokenString = encodeURIComponent(JSON.stringify(st));

          let requestParams = "?Action=getSigninToken";
          requestParams += `&SessionDuration=${duration}`;
          requestParams += `&Session=${sessionTokenString}`;

          let requestUrl = "https://signin.aws.amazon.com/federation" + requestParams;

          https.get(requestUrl, (resp) => {
            let data = '';

            // A chunk of data has been recieved.
            resp.on('data', (chunk) => {
              data += chunk;
            });

            // The whole response has been received. Print out the result.
            resp.on('end', () => {
              const signInToken = JSON.parse(data).SigninToken;

              requestParams = "?Action=login";
              requestParams += `&Issuer=${issuer}`;
              requestParams += `&Destination=https://console.aws.amazon.com/console/home?region=ca-central-1`;
              requestParams += `&SigninToken=${signInToken}`

              requestUrl = "https://signin.aws.amazon.com/federation" + requestParams;

              var response = {
                statusCode: 200,
                body: JSON.stringify({ Location: requestUrl })
              };

              callback(null, response);

            });

          }).on("error", (err) => {
            console.log("Error: " + err.message);
          });

        }
      });
    }

  }
  else {
    var response = {
      statusCode: 200,
      body: "Unknown Method"
    }
    callback(null, response)
  }
}


function parseSAMLResponse(samlResponse) {
  //let capturingRegex = new RegExp(">(?<provider>arn:aws:iam::\\d+:saml-provider/\\S+),(?<role>arn:aws::iam::(?<accountid>\\d+):role/(?<rolename>\\w+))<");
  let capturingRegex = new RegExp(">(arn:aws:iam::\\d+:saml-provider/[a-zA-Z0-9-_@=+.]+),(arn:aws:iam::(\\d+):role/([a-zA-Z0-9-_@=+.]+))<", "gi");
  ///>(arn:aws:iam::\d+:saml-provider\/\S+),(arn:aws:iam::(\d+):role\/(\w+))</gi
  let matches = samlResponse.matchAll(capturingRegex);

  let awsAccounts = {};
  for (const match of matches) {

    let awsAccount = {};
    awsAccount.providerArn = match[1];
    awsAccount.roleArn = match[2];
    awsAccount.accountId = match[3];
    awsAccount.roleName = match[4];

    if (awsAccounts[match[3]] == undefined) {
      awsAccounts[match[3]] = [awsAccount];
    } else {
      awsAccounts[match[3]].push(awsAccount);
    }
  }

  return awsAccounts;
}



//////////////////////////////////////////
////// Azure AD migration functions //////
//////////////////////////////////////////

// TODO: delete this after migration from Siteminder IDIR IDP to Azure AD IDIR IDP is complete

const kc_realm = process.env.kc_realm;
const kc_base_url = process.env.kc_base_url;
const kc_terraform_auth_client_id = process.env.kc_terraform_auth_client_id;
const kc_terraform_auth_client_secret = process.env.kc_terraform_auth_client_secret;

function checkSAMLForAzureIDP(saml_response) {
  return saml_response.includes("@azureidir");
}

function parseSAMLForEmail(saml_response) {
  let capturing_regex = new RegExp(">\\S+@azureidir<", "gm");
  let matches = saml_response.match(capturing_regex);
  let email = matches[0].replace('>', '').replace('@azureidir<', '')
  console.log('parsed SAML, Email is: ' + email)
  return email;
}

function makeHttpRequest(options, post_data) {
  return new Promise(function (resolve, reject) {
    let req = https.request(options, function (res) {
      if (res.statusCode < 200 || res.statusCode >= 300) {
        return reject(new Error('statusCode=' + res.statusCode));
      }
      let chunks = [];
      res.on("data", function (chunk) {
        chunks.push(chunk);
      });
      res.on("end", function () {
        let body = Buffer.concat(chunks);
        resolve(body);
      });
    });
    req.on('error', function (error) {
      reject(error);
    });
    req.write(post_data);
    req.end();
  });
}

async function getKeyCloakToken() {
  let options = {
    'method': 'POST',
    'hostname': kc_base_url,
    'path': '/auth/realms/' + kc_realm + '/protocol/openid-connect/token',
    'headers': {
      'Content-Type': 'application/x-www-form-urlencoded'
    },
    'maxRedirects': 20
  };
  let post_data = qs.stringify({
    'client_id': kc_terraform_auth_client_id,
    'client_secret': kc_terraform_auth_client_secret,
    'grant_type': 'client_credentials'
  });
  return makeHttpRequest(options, post_data);
}

async function getUsersWithEmail(headers, target_user_email) {
  let options = {
    'method': 'GET',
    'hostname': kc_base_url,
    'path': '/auth/admin/realms/' + kc_realm + '/users?email=' + target_user_email,
    'headers': headers,
    'maxRedirects': 20
  };
  let post_data = qs.stringify({});
  return makeHttpRequest(options, post_data);
}

async function getSiteminderUserGroups(headers, siteminder_user_id) {
  let options = {
    'method': 'GET',
    'hostname': kc_base_url,
    'path': '/auth/admin/realms/' + kc_realm + '/users/' + siteminder_user_id + '/groups',
    'headers': headers,
    'maxRedirects': 20
  };
  let post_data = qs.stringify({});
  return makeHttpRequest(options, post_data);
}

async function putAzureADUserGroup(headers, azure_ad_user_id, group_id) {
  let options = {
    'method': 'PUT',
    'hostname': kc_base_url,
    'path': '/auth/admin/realms/' + kc_realm + '/users/' + azure_ad_user_id + '/groups/' + group_id,
    'headers': headers,
    'maxRedirects': 20
  };
  let post_data = qs.stringify({});
  return makeHttpRequest(options, post_data);
}

async function disableSiteminderUser(headers, siteminder_user_id) {

  headers['Content-Type'] = 'application/json';

  let options = {
    'method': 'PUT',
    'hostname': kc_base_url,
    'path': '/auth/admin/realms/' + kc_realm + '/users/' + siteminder_user_id,
    'headers': headers,
    'maxRedirects': 20
  };
  var post_data = JSON.stringify({
    "enabled": false
  });
  return makeHttpRequest(options, post_data);
}

async function transferKeyCloakGroups(saml_response) {
  console.log("In transferKeyCloakGroups(), transferring groups from Sitminder IDP user to Azure AD IDP user");

  let token_response = await getKeyCloakToken();
  console.log("Retrieved Token is: " + JSON.parse(token_response).access_token);
  let headers = {
    'Authorization': 'Bearer ' + JSON.parse(token_response).access_token,
    'Content-Type': 'application/x-www-form-urlencoded'
  };

  let target_user_email = parseSAMLForEmail(saml_response);
  let user_array_response = await getUsersWithEmail(headers, target_user_email);
  console.log("Retrieved User List is: " + user_array_response);

  let common_email_users = JSON.parse(user_array_response);
  common_email_users.forEach(async function (user_a) {
    if (user_a.username.includes('@idir')) {
      let siteminder_user_groups_response = await getSiteminderUserGroups(headers, user_a.id);
      console.log('Sitminder User Groups are: ' + siteminder_user_groups_response);
      let siteminder_user_groups = JSON.parse(siteminder_user_groups_response);

      console.log('Transferring Groups');
      common_email_users.forEach(async function (user_b) {
        if (user_b.username.includes('@azureidir')) {
          siteminder_user_groups.forEach(async function (group) {
            await putAzureADUserGroup(headers, user_b.id, group.id);
          });
          console.log('Disabling Siteminder User');
          await disableSiteminderUser(headers, user_a.id);
        }
      });
    }
  });
  console.log("Finished transferring groups from Sitminder IDP user to Azure AD IDP user");
}