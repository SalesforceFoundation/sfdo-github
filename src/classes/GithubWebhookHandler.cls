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
        String github_event_type = req.headers.get('X-GitHub-Event');
        String event_body = '';
        String event_title = '';
        String event_user = '';
        Integer event_id;
        String event_url = '';
        String event_repo_name = '';
        Integer event_number;
        String event_action = '';

        //need to rename reserved to support the needed number field
        body = Github.renameReserved(body);

        if (github_event_type == 'issue_comment'){
          Github.IssueCommentEvent evt = (Github.IssueCommentEvent) JSON.deserialize(body, Github.IssueCommentEvent.class);
          event_body = evt.comment.body;
          event_title = evt.issue.title; //this is correct
          event_user = evt.comment.user.login;
          event_id = evt.comment.id;
          event_url = evt.comment.html_url;
          event_repo_name = evt.repository.name;
          event_number = evt.issue.num;
          event_action = evt.action;
        }
        else if (github_event_type == 'issues'){
          Github.IssuesEvent evt = (Github.IssuesEvent) JSON.deserialize(body, Github.IssuesEvent.class);
          event_body = evt.issue.body;
          event_title = evt.issue.title;
          event_user = evt.issue.user.login;
          event_id = evt.issue.id;
          event_url = evt.issue.html_url;
          event_repo_name = evt.repository.name;
          event_number = evt.issue.num;
          event_action = evt.action;
        }
        else if (github_event_type == 'pull_request'){
          Github.PullRequestEvent evt = (Github.PullRequestEvent) JSON.deserialize(body, Github.PullRequestEvent.class);
          event_body = evt.pull_request.body;
          event_title = evt.pull_request.title;
          event_user = evt.pull_request.user.login;
          event_id = evt.pull_request.id;
          event_url = evt.pull_request.html_url;
          event_repo_name = evt.repository.name;
          event_number = evt.pull_request.num;
          event_action = evt.action;
        }

        ResponseWrapper resp;

        String uid = event_repo_name + '_' + String.valueOf(event_number);
        List<Github_Link__c> link_list = new List<Github_Link__c>();
        link_list = [select id, Work__c from Github_Link__c where Github_Unique_Id__c = :uid];

        //handle lurch commands
        if (event_body.containsIgnoreCase('lurch:')) {
            GithubToAgileAccelerator.Action action = GithubToAgileAccelerator.parseAction(event_body);
            if (action.type == 'add' || action.type == 'remove' || action.type == 'attach') {
                Github_Request__c gitRequest = new Github_Request__c(
                    Action__c = action.type,
                    Title__c = event_title,
                    Body__c = event_body,
                    Comment__c = event_body,
                    Status__c = 'New',
                    Target__c = action.target,
                    Github_Event__c = github_event_type + ' ' + event_action,
                    Github_Record_Id__c = String.valueOf(event_id),
                    Github_Record_Type__c = github_event_type,
                    Github_Record_URL__c = event_url,
                    Github_Repository__c = event_repo_name,
                    Github_Username__c = event_user,
                    Github_Record_Number__c = String.valueOf(event_number),
                    JSON__c = body
                );
                insert gitRequest;
                resp = new ResponseWrapper('Request received.');
            } else {
                resp = new ResponseWrapper('Unable to process request.');
            }
        }

        //handle comments on a tracked record
        else if (github_event_type == 'issue_comment' && !event_body.containsIgnoreCase('Tracking <a href')){
          //we have a valid linked issue for this Comment
          //so enter a new request to be picked up by the scheduler
          if (!link_list.isEmpty()){
            //create a list of work items that need the comment added
            List<Github_Request__c> gr = new List<Github_Request__c>();
            for (Github_Link__c gl : link_list){
              Github_Request__c gitRequest = new Github_Request__c(
                  Action__c = 'comment',
                  Title__c = event_title,
                  Body__c = event_body,
                  Comment__c = event_body,
                  Status__c = 'New',
                  Target__c = gl.Work__c,
                  Github_Event__c = github_event_type + ' ' + event_action,
                  Github_Record_Id__c = String.valueOf(event_id),
                  Github_Record_Type__c = github_event_type,
                  Github_Record_URL__c = event_url,
                  Github_Repository__c = event_repo_name,
                  Github_Username__c = event_user,
                  Github_Record_Number__c = String.valueOf(event_number),
                  JSON__c = body
              );
              gr.add(gitRequest);
            }
            if (!gr.isEmpty())
              insert gr;
            resp = new ResponseWrapper('Request received.');
          } else {
            resp = new ResponseWrapper('Unknown issue.');
          }
        }

        //handle opening/closing of tracked github issue
        else if (github_event_type == 'issues'){


        }


        else {
            resp = new ResponseWrapper('No command received.');
        }
        return resp;
    }
}
