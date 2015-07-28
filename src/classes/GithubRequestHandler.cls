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
    }
    

}