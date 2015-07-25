global without sharing class GithubToAgileAccelerator {
	//lurch.processGithubEvent = function (event_name, event_id, event_body) {
    /*only listen and forward:
    1.  anything with **lurch:add from a known user
    2.  anything with **lurch:attach w-xxxxxxxxxxxx or epic:XXXXXXX from a known user
    3.  anything with **lurch:remove from a known user
    4.  anything currently being actively tracked, regardless of user
    5.  pull requests from a known user
    (?) 5.  milestones
    */

    private static Set<String> authorizedUsers {
        get {
            if (authorizedUsers == null) {
                authorizedUsers = new Set<String>();
                List<Github_Integration_Users__c> users = Github_Integration_Users__c.getAll().values();
                for (Github_Integration_Users__c user : users) {
                    authorizedUsers.add(user.Github_Username__c);   
                }
            }
            return authorizedUsers;
        }
        set;
    }

    global static Boolean isAuthorizedUser(String githubUsername) {
        return authorizedUsers.contains(githubUsername);
    }

    global static Boolean isRecognizedCommand(String command) {
        Set<String> recognizedCommands = new Set<String>{ 'add', 'attach', 'remove' };
        return (recognizedCommands.contains(command));
    }

    global static Boolean isMappedRepository(String repositoryName) {
        return repositoryMap.keySet().contains(repositoryName);
    }

    private static Map<String, Github_Repositories__c> repositoryMap {
        get {
            if (repositoryMap == null) {
                repositoryMap = Github_Repositories__c.getall();
            }
            return repositoryMap;
        }
        set;
    }

    global class Action {
        global String type;
        global String target;
        global String body;
    }

    public static Action parseAction(String body) {
        Pattern p = Pattern.compile('\\*\\*lurch:((?i)[a-z]+)( (?i)w-[0-9]+)?');
        Matcher pm = p.matcher( body );
        pm.find();
        Action act = new Action();
        act.type = pm.group(1);
        if (pm.group(2) != null) {
            act.target = pm.group(2).trim();    
        }
        act.body = pm.replaceAll('').trim();

        return act;
    }

    public static String getUniqueId(Github_Request__c request) {
        return request.Github_Repository__c + '_' + request.Github_Record_Type__c + '_' + request.Github_Record_Id__c; 
    }

    public static List<GitHub_Link__c> addWorkRecords(List<Github_Request__c> gitRequests) {
        Map<Github_Request__c, agf__ADM_Work__c> workToCreate = new Map<Github_Request__c, agf__ADM_Work__c>();
        List<GitHub_Link__c> linksToCreate = new List<GitHub_Link__c>();

        for (Github_Request__c gitRequest : gitRequests) {
            // create the work record
            workToCreate.put( gitRequest, new agf__ADM_Work__c (
                agf__Details__c = gitRequest.Body__c,
                agf__Perforce_Status__c = 'Attached',
                agf__Product_Tag__c = repositoryMap.get(gitRequest.Github_Repository__c).Product_Tag__c,
                agf__Status__c = 'New - From Github',
                agf__Subject__c = gitRequest.Title__c
            ));
            gitRequest.Status__c = 'Processed';
        }
        // insert work
        if (!workToCreate.values().isEmpty()) {
            insert workToCreate.values();
        }

        for (Github_Request__c gitRequest : workToCreate.keySet()) {
            // create link to work
            linksToCreate.add( new GitHub_Link__c(
                GitHub_Id__c = gitRequest.Github_Record_Id__c, 
                GitHub_Type__c = gitRequest.Github_Record_Type__c,
                Github_URL__c = gitRequest.Github_Record_URL__c,
                Work__c = workToCreate.get(gitRequest).Id
            ));
            gitRequest.Status__c = 'Processed';
        }

        // insert links
        if (!linksToCreate.isEmpty()) {
            insert linksToCreate;
        }

        // update requests with new status
        update gitRequests;

        return linksToCreate;
    }
/*
    public static List<GitHub_Link__c> attachWorkToRecords(List<Github_Request__c> gitRequests) {

    }

/*
    global static Id attachToWorkRecord(Github.Issue issue, String workName){
        // try to find a work record with the matching name
        List<agf__ADM_Work__c> matchingWork = [ SELECT Id FROM agf__ADM_Work__c WHERE Name = :workName];
        if (matchingWork.size() > 0) {
            // if there's a match, make sure there's no existing github link
            List<GitHub_Link__c> matchingLinks = [ SELECT Id, GitHub_Id__c, Work__c, Work__r.Name 
                FROM GitHub_Link__c 
                WHERE Work__r.Name = :workName 
                AND GitHub_Id__c = :issue.id ];
            if (matchingLinks.size() > 0) {
                return matchingLinks[0].Work__c;
            } else {
                // if the work matches but there's no link yet, create one
                GitHub_Link__c link = new GitHub_Link__c(
                    GitHub_Id__c = issue.id, 
                    GitHub_Type__c = 'Issue',
                    Work__c = matchingWork[0].Id
                );
                insert link;
                return matchingWork[0].Id;
            }

        } else {
            // if there's no matching work record, return null
            return null;    
        }        
    }

    global static Id attachToEpicRecord(Github.Issue issue, String epicName){
        // TODO: implement
        return null;
    }

    global static Boolean detachFromAllRecords(Github.Issue issue){
        Boolean isDeleted = false;
        List<GitHub_Link__c> linksToDelete = 
            [ SELECT Id FROM GitHub_Link__c WHERE GitHub_Id__c = :issue.id ];
        if (!linksToDelete.isEmpty()) {
            delete linksToDelete;
            isDeleted = true;
        }
        return isDeleted;
    }*/
    
}