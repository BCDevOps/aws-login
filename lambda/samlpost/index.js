'use strict'

let fs = require("fs");
let path = require("path");
let AWS = require("aws-sdk");
let https = require('https');

exports.handler = function (event, context, callback) {

    if (event.path == "/" && event.httpMethod == "POST") {
        const fileName = "index.html";

        let resolved = null;
        if (process.env.LAMBDA_TASK_ROOT) {
            resolved = path.resolve(process.env.LAMBDA_TASK_ROOT, fileName);
        } else {
            resolved = path.resolve(__dirname, fileName);
        }

        const data = fs.readFileSync(resolved, 'utf8');

        let samlResponse = event.body.replace('SAMLResponse=', '');

        let html = data.replace("##SAMLRESPONSE##", decodeURIComponent(samlResponse));
      
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
    else if (event.path == "/consolelogin" && event.httpMethod == "POST") {

        if (event.body) {
            
            let body = JSON.parse(event.body)

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
                            requestParams += `&Destination=https://console.aws.amazon.com/`;
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
