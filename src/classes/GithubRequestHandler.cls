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
                Github_Repository__c, Github_Username__c, Status__c, Github_Unique_Id__c
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

        // TODO: post results back to github

        //Github gh = new Github(String repo, String token);

        for (String s : requestsByAction.keySet()) {
          //requests by action contains the updated lists thanks to the puts above
          List<Github_Request__c> ghr = requestsByAction.get(s);
          String body_text = '';
          if (s == 'add'){ body_text = 'Added: '; }
          if (s == 'attach'){ body_text = 'Attached: '; }
          if (s == 'remove'){ body_text = ' Detached: '; }

          for (Github_Request__c greq : ghr){
            //only write back the successfully processed results
            if(greq.Status__c == 'Processed'){

              Github_Repositories__c gr = Github_Repositories__c.getValues(greq.Github_Repository__c);

              //create a new GH object
              Github gh = new Github(greq.Github_Repository__c, gr.Token__c);
              Github.Comment comment = new Github.Comment();
              comment.body = body_text + greq.MD_Work_Link__c;
              comment.id = Integer.valueOf(greq.Github_Record_Id__c);
              gh.issues.createComment(comment);
            }
          }
        }



    }//close processRequests
}
