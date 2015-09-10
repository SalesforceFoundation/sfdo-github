### About

Tool for supporting Github-Agile Accelerator integration

### Install

* Deploy contents of the src folder to your Salesforce instance
* Using Force.com Sites, setup an unauthenticted endpoint to listen for the Github hooks.  You can use an existing guest site user to assign access to the Apex REST service located in GithubWebhookHandler.cls  By default, the service points to
```
https://<mysalesforcedomain>/services/apexrest/github/webhook
```
* Add your repo, product tag Id and personal token to the custom settings Github_Repositories__c
* Add your username to the Github_Integration_Users__c setting
* Schedule the GithubRequestHandler scheduled job for as frequently as you'd like.  This process will examine incoming Github requests as process them as appropriate
```
NOTE:  This means your action in Github will be delayed in appearing in Salesforce and vice-versa until the scheduled job as an opportunity to run and clear the queue
```

### Usage

The following commands are supported:

##### add
```
**lurch: add
```
Adding an existing Github issue or pull request, either in the issue body or in a comment.  This will create a new Agile Accelerator work item utilizing the default product tag for this repository, create a Chatter comment on the work, and post a link to the work back to Github.  Any new comments on this issue will appear as Chatter comments on the now linked work item
##### detach
```
**lurch: detach
```
Remove any link between this Github issue and its corresponding work items.  Comments will no longer appears as a part of this work item's feed, and a notice of a successful detach will appear in Github
##### attach
```
**lurch: attach W-123456
```
Attach this Github issue to an existing Agile Accelerator work item.  Any future issue comments will appear in the Chatter feed for this work item, and a notice of a successful attach will appear in Github

#### Meta

Released under the [BSD 3-Clause License](http://www.opensource.org/licenses/BSD-3-Clause).
