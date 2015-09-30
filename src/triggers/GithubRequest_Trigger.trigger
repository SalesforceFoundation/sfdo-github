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
                gitRequest.Status__c = 'Rejected - Unauthorized';
            } else if (gitRequest.Github_Repository__c == null ||
                !GithubToAgileAccelerator.isMappedRepository(gitRequest.Github_Repository__c)) {
                // reject requests from unmapped repositories
                gitRequest.Status__c = 'Rejected - Unrecognized Repository';
            } else if (gitRequest.Action__c != null &&
                // reject requests with unrecognized commands
                !GithubToAgileAccelerator.isRecognizedCommand(gitRequest.Action__c)) {
                gitRequest.Status__c = 'Rejected - Unrecognized Command';
            }
        }
    }
}
