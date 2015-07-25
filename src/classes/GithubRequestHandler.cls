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

        for (Github_Request__c githubRequest : 
            [ SELECT Id, Body__c, Title__c, Comment__c, Action__c, Target__c, 
                Github_Record_Id__c, Github_Record_Type__c, Github_Record_URL__c,
                Github_Repository__c, Github_Username__c, Status__c 
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
            for (Integer i = 0; i < requestsToAdd.size(); i++) {
                if (lastAction.get(requestsToAdd[i].Github_Unique_Id__c) != 'add') {
                    requestsToAdd.remove(i);
                }
            }
            GithubToAgileAccelerator.addWorkRecords(requestsToAdd);
        }
        
        // process all the attaches

        // process all the detaches
        
        // TODO: post results back to github 
    }
    

}