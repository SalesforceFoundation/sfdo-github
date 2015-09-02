#### About

Tool for supporting Github-Agile Accelerator integration

#### Install

* Deploy contents of the src folder to your Salesforce instance
* Using Force.com Sites, setup an unauthenticted endpoint to listen for the Github hooks.  You can use an existing guest site user to assign access to the Apex REST service located in GithubWebhookHandler.cls  By default, the service points to
```
https://<mysalesforcedomain>/services/apexrest/github/webhook
```
*




#### Meta

Released under the [BSD 3-Clause License](http://www.opensource.org/licenses/BSD-3-Clause).
