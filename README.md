# KintoneDeploy
KintoneDeploy is a tiny deployment tool for Kintone. It deploys JS, CSS and URLs as Kintone app's customization.
You can deploy those things by simple CLI.

## Installation

```bash
$ curl -s -L -O https://github.com/maloninc/kintone_deploy/raw/master/gems/kintone_deploy-x.x.x.gem
$ gem install kintone_deploy-x.x.x.gem
```

## Usage

```bash
Usage: kintone_deploy [options]
    -i [app.json]                    app.json
    -d domain                        Domain name
    -u user id                       Account name
    -p password                      Account password
    -t                               Deploy preview environment
    -v                               Verify deployment
    -b, --basic-id user id           Basic Auth ID
    -q, --basic-pw password          Basic Auth password
```

## app.json

```javascript
{
    "id": 1234,
    "name": "My Greate App",
    "description": "",
    "js":[
        "greate.js",
        "amazing.js",
        "https://example.com/example.js"
    ],
    "css":[
        "great.css"
    ],
    "mobile_js":[
        "greate-mobile.js"
    ]
}
```

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

