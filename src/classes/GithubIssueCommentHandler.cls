@RestResource(urlMapping='/github/issueCommentEvent')
global class GithubIssueCommentHandler {

    private Boolean checkSecret(String body) {
        return true;
    }

    private static Boolean isAuthorizedUser(String githubUserId) {
        // TODO: check this against user field
        return true;
    }

    global class ResponseWrapper {
        global Id workId { get; set; }

        global ResponseWrapper(String projectId) {
            this.workId = workId;
        }
    }
    
    @HttpPost
    global static ResponseWrapper receiveEvent() {
        RestRequest req = RestContext.request;
        String body = req.requestBody.toString();
        Github.IssueCommentEvent issueCommentEvent = (Github.IssueCommentEvent) JSON.deserialize(body, Github.IssueCommentEvent.class);
        Id recordId;   

        if (!isAuthorizedUser(null)) {
            return null;
        }

        if (issueCommentEvent.comment.body.contains('**lurch:')) {

            String action = 'TODO'; // replace with regex to parse out action
            String target = 'TODO'; // replace with regex for epic or work
            if (action == 'add') { 
                // **lurch:add
                recordId = GithubToAgileAccelerator.addWorkRecord(issueCommentEvent);
            } else if (action == 'attach') { 
                if (target.containsIgnoreCase('w-')) { 
                    // **lurch:attach W-xx01010010xx
                    recordId = GithubToAgileAccelerator.attachToWorkRecord(issueCommentEvent, target);    
                } else {
                    // **lurch:attach epic:asdflkjsadlkfj
                    recordId = GithubToAgileAccelerator.attachToEpicRecord(issueCommentEvent, target);    
                }                
            } else if (action == 'remove') {
                // **lurch:remove
                recordId = GithubToAgileAccelerator.detachFromAllRecords(issueCommentEvent);
            }
        }

        return new ResponseWrapper(recordId);
    }

}