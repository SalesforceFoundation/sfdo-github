@RestResource(urlMapping='/github/webhook')
global without sharing class GithubWebhookHandler {

    //private Boolean checkSecret(String body) {
    //    return true;
    //}

    global class ResponseWrapper {
        global String message { get; set; }

        global ResponseWrapper(String message) {
            this.message = message;
        }
    }

    @HttpPost
    global static ResponseWrapper receiveEvent() {
        RestRequest req = RestContext.request;
        String body = req.requestBody.toString();

        /* Check the event type and deserialize to the actual type that is created */

        /* Check if either A: This issue is actively being tracked already or B: the user is authenticated & there's a lurch command
        /* or C: The user is authenticated and its an action not requiring a Lurch command (milestone created, labeling, whatever) */



        Github.IssueCommentEvent evt = (Github.IssueCommentEvent) JSON.deserialize(body, Github.IssueCommentEvent.class);

        ResponseWrapper resp;

        if (evt.comment.body.contains('lurch:')) {
            GithubToAgileAccelerator.Action action = GithubToAgileAccelerator.parseAction(evt.comment.body);
            if (action.type == 'add' || action.type == 'remove' || action.type == 'attach') {
                Github_Request__c gitRequest = new Github_Request__c(
                    Action__c = action.type,
                    Title__c = evt.issue.title,
                    Body__c = evt.issue.body,
                    Comment__c = evt.comment.body,
                    Status__c = 'New',
                    Target__c = action.target,
                    Github_Event__c = 'Issue Comment ' + evt.action,
                    Github_Record_Id__c = evt.issue.id,
                    Github_Record_Type__c = 'Issue',
                    Github_Record_URL__c = evt.issue.url,
                    Github_Repository__c = evt.repository.name,
                    Github_Username__c = evt.comment.user.login,
                    JSON__c = body
                );
                insert gitRequest;
                resp = new ResponseWrapper('Request received.');
            } else {
                resp = new ResponseWrapper('Unable to process request.');
            }
        } else {
            resp = new ResponseWrapper('No command received.');
        }

        return resp;
    }



}
