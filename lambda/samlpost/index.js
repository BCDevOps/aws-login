'use strict'

let fs = require("fs");
let path = require("path");
let AWS = require("aws-sdk");
let https = require('https');
var qs = require('querystring');

exports.handler = function (event, context, callback) {
  if ((event.path == "/redirect" && event.httpMethod == "GET") || (event.path == "/" && event.httpMethod == "GET")) {
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
