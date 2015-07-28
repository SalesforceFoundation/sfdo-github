trigger GithubRequest_Trigger on Github_Request__c (before insert, after insert) {
    if (Trigger.isBefore && Trigger.isInsert) {
        Boolean processRequests = false;
        Map<String, Github_Request__c> requestsToCheck = new Map<String, Github_Request__c>();

        for (Github_Request__c gitRequest : trigger.new) {
            // stamp the time we'll use to order the results
            // using this instead of created date so we can manipulate times for tests
            gitRequest.Queue_Datestamp__c = gitRequest.CreatedDate;
            // populate a unique identifier so we don't confuse Issue 9 with Pull Request 9
            gitRequest.Github_Unique_Id__c = GithubToAgileAccelerator.getUniqueId(gitRequest);

            if (gitRequest.Github_Username__c == null || 
                !GithubToAgileAccelerator.isAuthorizedUser(gitRequest.Github_Username__c)) {
                // reject requests from unrecognized users
                gitRequest.Status__c = 'Rejected';    
            } else if (gitRequest.Action__c != null &&
                // reject requests with unrecognized commands 
                !GithubToAgileAccelerator.isRecognizedCommand(gitRequest.Action__c)) {
                gitRequest.Status__c = 'Rejected';
            } else if (gitRequest.Github_Repository__c == null || 
                !GithubToAgileAccelerator.isMappedRepository(gitRequest.Github_Repository__c)) {
                // reject requests from unmapped repositories
                gitRequest.Status__c = 'Rejected';
            } else if (gitRequest.Action__c == null) {
                // check records with no commands to see if they're from tracked records
                requestsToCheck.put(gitRequest.Github_Record_Id__c, gitRequest); 
            } else {
                processRequests = true;
            }
        }

        if (requestsToCheck.size() > 0) {
            // only check against existing links if there are still requests to check

            Set<String> links = new Set<String>();

            for (Github_Link__c link : [ SELECT Id, GitHub_Type__c, GitHub_Unique_Id__c 
                                            FROM Github_Link__c 
                                            WHERE GitHub_Unique_Id__c in :requestsToCheck.keySet() ]) {
                links.add(link.GitHub_Unique_Id__c);
            }

            // reject requests with no commands if they're from untracked records   
            for (Github_Request__c requestToCheck : requestsToCheck.values()) {
                if (!links.contains(requestToCheck.GitHub_Unique_Id__c)) {
                    requestToCheck.Status__c = 'Rejected';
                } else {
                    processRequests = true;
                }
            }
        } 

        if (processRequests) {
            // if there are still requests to process
            // see if there's a scheduled job to process them

            /* we can't actually schedule the job here because it gets scheduled as the guest user

            // if not, schedule a new job
            GithubRequestHandler handler = new GithubRequestHandler();
            DateTime now = System.now().addSeconds(10);

            // Seconds Minutes Hours Day_of_month Month Day_of_week optional_year
            String chronExpression = now.secondGmt() + ' ' + now.minuteGmt() + ' ' + now.hourGmt() + ' ' + now.dayGmt() + ' ' + now.monthGmt() + ' ?';
            System.debug(chronExpression);
            String jobID = system.schedule('Process GitHub Requests', chronExpression, handler);
            */    
        }
        
    } 

}