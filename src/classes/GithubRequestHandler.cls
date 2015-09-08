global without sharing class GithubRequestHandler implements Schedulable {

    global void execute(SchedulableContext sc) {
        processRequests();
    }

    global void processRequests() {
        // action => list of requests
        // i.e. add => list of requests to add
        Map<String, List<Github_Request__c>> requestsByAction = new Map<String, List<Github_Request__c>>();

        // github record id => last action listed on that Id
        Map<String, String> lastAction = new Map<String, String>();
        List<GitHub_Link__c> processedLinks = new List<GitHub_Link__c>();

        for (Github_Request__c githubRequest :
            [ SELECT Id, Body__c, Title__c, Comment__c, Action__c, Target__c,
                Github_Record_Id__c, Github_Record_Type__c, Github_Record_URL__c,
                Github_Repository__c, Github_Username__c, Status__c, Github_Unique_Id__c,
                Github_Record_Number__c
                FROM Github_Request__c
                WHERE Status__c = 'New'
                ORDER BY CreatedDate
            ]) {

            // add to action map
            if (requestsByAction.get(githubRequest.Action__c) == null) {
                requestsByAction.put(githubRequest.Action__c, new List<Github_Request__c>{ githubRequest });
            } else {
                requestsByAction.get(githubRequest.Action__c).add(githubRequest);
            }
            lastAction.put(githubRequest.Github_Unique_Id__c, githubRequest.Action__c);
        }

        // NOTE: if the same record shows up in the same batch multiple times, only the last action should be honored

        // process all the adds
        if (requestsByAction.get('add') != null) {
            List<Github_Request__c> requestsToAdd = requestsByAction.get('add');
            requestsByAction.put('add', GithubToAgileAccelerator.addWorkRecords(requestsToAdd));
        }

        // process all the attaches
        if (requestsByAction.get('attach') != null) {
            List<Github_Request__c> requestsToAttach = requestsByAction.get('attach');
            requestsByAction.put('attach', GithubToAgileAccelerator.attachWorkToRecords(requestsToAttach));
        }

        // process all the Comment
        if (requestsByAction.get('comment') != null) {
          List<Github_Request__c> requestsToComment = requestsByAction.get('comment');
          requestsByAction.put('comment', GithubToAgileAccelerator.postComment(requestsToComment));
        }

        // process all the detaches
        if (requestsByAction.get('remove') != null) {
            List<Github_Request__c> requestsToDetach = requestsByAction.get('remove');
            // only process detaches if 'detach' was the last command for this github record
            for (Integer i = 0; i < requestsToDetach.size(); i++) {
                if (lastAction.get(requestsToDetach[i].Github_Unique_Id__c) != 'remove') {
                    requestsToDetach.remove(i);
                }
            }
            requestsByAction.put('remove', GithubToAgileAccelerator.detachFromAllRecords(requestsToDetach));
        }

        //handle posting back to github for lurch actions requiring confirmation
        for (String s : requestsByAction.keySet()) {

          if (s == 'add' || s == 'attach' || s == 'remove'){
            //requests by action contains the updated lists thanks to the puts above
            List<Github_Request__c> ghr = requestsByAction.get(s);
            String body_text = 'Tracking ';
            if (s == 'remove'){ body_text = 'Detached '; }

            for (Github_Request__c greq : ghr){
              //only write back the successfully processed results
              if(greq.Status__c == 'Processed'){

                Github_Repositories__c gr = Github_Repositories__c.getValues(greq.Github_Repository__c);

                Github.Comment comment = new Github.Comment();
                comment.body = body_text + greq.Work_Link__c;
                comment.id = Integer.valueOf(greq.Github_Record_Number__c);

                //we should have a call-back mechanism to ensure non-sent post-backs are picked
                //the next time throught the scheduler... you know, for v2.
                Boolean callStackLimitExceeded = Limits.getFutureCalls() >= Limits.getLimitFutureCalls();
                if (!callStackLimitExceeded) {
                  //call the @future version of the callout
                  GithubRequestHandler.createGithubComment(JSON.serialize(comment), gr.Token__c, greq.Github_Repository__c);
                }
              }
            }
          }
        } 
    }//close processRequests

  @future(callout=true)
  static void createGithubComment(String serializedComment, String github_token, String repository) {
      Github gh = new Github(repository, github_token);
      if (!Test.isRunningTest())
        gh.issues.createComment((Github.Comment)JSON.deserialize(serializedComment, Github.Comment.class));
  }
}
