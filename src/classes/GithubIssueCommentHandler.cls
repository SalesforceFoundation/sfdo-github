@RestResource(urlMapping='/github/issueCommentEvent')
global class GithubIssueCommentHandler {

    private Boolean checkSecret(String body) {
        return true;
    }

    global class ResponseWrapper {
        global Id recordId { get; set; }

        global ResponseWrapper(String recordId) {
            this.recordId = (Id)recordId;
        }

        global ResponseWrapper(Id recordId) {
            this.recordId = recordId;
        }
    }
    
    @HttpPost
    global static ResponseWrapper receiveEvent() {
        RestRequest req = RestContext.request;
        String body = req.requestBody.toString();
        Github.IssueCommentEvent issueCommentEvent = (Github.IssueCommentEvent) JSON.deserialize(body, Github.IssueCommentEvent.class);
        Id recordId;   

        if (!GithubToAgileAccelerator.isAuthorizedUser(issueCommentEvent.comment.user.login)) {
            // TODO: log an error if the user isn't authorized
            return null;
        }

        if (issueCommentEvent.comment.body.contains('**lurch:')) {
            CommentAction action = parseAction(IssueCommentEvent.comment.body);

            if (action.type == 'add') { 
                // **lurch:add
                issueCommentEvent.comment.body = action.body;
                recordId = GithubToAgileAccelerator.addWorkRecord(issueCommentEvent);
            } else if (action.type == 'attach') { 
                if (action.recordName.containsIgnoreCase('w-')) { 
                    // **lurch:attach W-xx01010010xx
                    recordId = GithubToAgileAccelerator.attachToWorkRecord(issueCommentEvent, action.recordName);    
                } else {
                    // TODO
                    // **lurch:attach epic:asdflkjsadlkfj
                    recordId = GithubToAgileAccelerator.attachToEpicRecord(issueCommentEvent, action.recordName);    
                }                
            } else if (action.type == 'remove') {
                // **lurch:remove
                recordId = GithubToAgileAccelerator.detachFromAllRecords(issueCommentEvent);
            }
        }

        return new ResponseWrapper(recordId);
    }

    global class CommentAction {
        global String type;
        global String recordName;
        global String body;
    }

    @TestVisible
    private static CommentAction parseAction(String commentBody) {
        Pattern p = Pattern.compile('\\*\\*lurch:((?i)[a-z]+)( (?i)w-[0-9]+)?');
        Matcher pm = p.matcher( commentBody );
        pm.find();
        CommentAction action = new CommentAction();
        action.type = pm.group(1);
        if (pm.group(2) != null) {
            action.recordName = pm.group(2).trim();    
        }
        action.body = pm.replaceAll('').trim();

        return action;
    }

}