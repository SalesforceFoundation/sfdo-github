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
    static String INSTANCE_URL = 'https://foundation--kbromer.cs30.my.salesforce.com/';

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
        Pattern p = Pattern.compile('[\\*\\*]{2}[lL]urch:\s*((?i)[a-z]+)( (?i)w-[0-9]+)?');
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

    public static List<Github_Request__c> addWorkRecords(List<Github_Request__c> gitRequests) {
        // github unique Id => work
        Map<String, agf__ADM_Work__c> workToCreate = new Map<String, agf__ADM_Work__c>();

        // Id => work
        Map<Id, agf__ADM_Work__c> newWorkWithName = new Map<Id, agf__ADM_Work__c>();

        // github unique Id => request
        Map<String, Github_Request__c> requests = new Map<String, Github_Request__c>();
        List<GitHub_Link__c> linksToCreate = new List<GitHub_Link__c>();

        for (Github_Request__c gitRequest : gitRequests) {
            // create the work record
            workToCreate.put( gitRequest.Github_Unique_Id__c, new agf__ADM_Work__c (
                agf__Details__c = gitRequest.Body__c,
                agf__Perforce_Status__c = 'Attached',
                agf__Product_Tag__c = repositoryMap.get(gitRequest.Github_Repository__c).Product_Tag__c,
                agf__Status__c = 'New - From Github',
                agf__Subject__c = gitRequest.Title__c
            ));
            requests.put(gitRequest.Github_Unique_Id__c, gitRequest);
        }
        // insert work
        if (!workToCreate.values().isEmpty()) {
            insert workToCreate.values();
            // requery for created name/etc. to provide links
            newWorkWithName = new Map<Id, agf__ADM_Work__c>([select id, Name from agf__ADM_Work__c where id IN :workToCreate.values()]);
        }

        for (String uniqueId : workToCreate.keySet()) {
            // create link to work
            linksToCreate.add( new GitHub_Link__c(
                GitHub_Unique_Id__c = requests.get(uniqueId).Github_Unique_Id__c,
                GitHub_Type__c = requests.get(uniqueId).Github_Record_Type__c,
                Github_URL__c = requests.get(uniqueId).Github_Record_URL__c,
                Work__c = workToCreate.get(uniqueId).Id
            ));
            requests.get(uniqueId).Status__c = 'Processed';
            requests.get(uniqueId).MD_Work_Link__c = '[' + newWorkWithName.get(workToCreate.get(uniqueId).Id).Name + ']' + '(' + INSTANCE_URL + workToCreate.get(uniqueId).Id + ')';
            requests.get(uniqueId).Target__c = newWorkWithName.get(workToCreate.get(uniqueId).Id).Name;
        }

        // insert links
        if (!linksToCreate.isEmpty()) {
            insert linksToCreate;
        }

        // update requests with new status
        update requests.values();

        return requests.values();
    }

    public static List<Github_Request__c> attachWorkToRecords(List<Github_Request__c> gitRequests) {
        List<GitHub_Link__c> linksToCreate = new List<GitHub_Link__c>();

        Map<String, Id> workNameWithId = new Map<String, Id>();
        Map<String, Github_Request__c> requestMap = new Map<String, Github_Request__c>();
        Map<String, GitHub_Link__c> linkMap = new Map<String, GitHub_Link__c>();

        for (Github_Request__c gitRequest : gitRequests) {
            if (gitRequest.Target__c != null) {
                requestMap.put(gitRequest.Github_Unique_Id__c, gitRequest);
                workNameWithId.put(gitRequest.Target__c, null);
            } else {
                gitRequest.Status__c = 'Rejected';
            }
        }

        //// try to find a work record with the matching name
        for (agf__ADM_Work__c work : [ SELECT Id, Name
                                        FROM agf__ADM_Work__c
                                        WHERE Name in :workNameWithId.keySet()]) {
            workNameWithId.put(work.Name, work.Id);
        }

        // look for links with matching links and work name
        for (GitHub_Link__c link : [ SELECT Id, Work__r.Name, Github_Unique_Id__c
                                        FROM GitHub_Link__c
                                        WHERE Github_Unique_Id__c in :requestMap.keySet() ]) {
            linkMap.put(link.Github_Unique_Id__c, link);
        }

        for (Github_Request__c gitRequest : gitRequests) {
            if (linkMap.get(gitRequest.Github_Unique_Id__c) != null && requestMap.get(gitRequest.Github_Unique_Id__c).Target__c == linkMap.get(gitRequest.Github_Unique_Id__c).Work__r.Name) {
                // link already exists
                gitRequest.Status__c = 'Rejected';
            } else if (workNameWithId.get(gitRequest.Target__c) != null) {
                // work exists but link does not - create it
                linksToCreate.add( new GitHub_Link__c(
                    GitHub_Unique_Id__c = gitRequest.Github_Unique_Id__c,
                    GitHub_Type__c = gitRequest.Github_Record_Type__c,
                    Github_URL__c = gitRequest.Github_Record_URL__c,
                    Work__c = workNameWithId.get(gitRequest.Target__c)
                ));
                gitRequest.Status__c = 'Processed';
                gitRequest.MD_Work_Link__c = '[' + gitRequest.Target__c + ']' + '(' + INSTANCE_URL + workNameWithId.get(gitRequest.Target__c) + ')';
            } else {
                // work not found
                gitRequest.Status__c = 'Rejected';
            }
        }

        if (!linksToCreate.isEmpty()) {
            insert linksToCreate;
        }

        update gitRequests;

        return gitRequests;
    }

    public static List<Github_Request__c> detachFromAllRecords(List<Github_Request__c> gitRequests){
        Set<String> githubUniqueIds = new Set<String>();
        for (Github_Request__c gitRequest : gitRequests) {
            githubUniqueIds.add(gitRequest.Github_Unique_Id__c);
            gitRequest.Status__c = 'Processed';
        }

        List<GitHub_Link__c> linksToDelete =
            [ SELECT Id FROM GitHub_Link__c WHERE Github_Unique_Id__c in :githubUniqueIds ];
        if (!linksToDelete.isEmpty()) {
            delete linksToDelete;
        }

        update gitRequests;

        return gitRequests;
    }

/*

    global static Id attachToEpicRecord(Github.Issue issue, String epicName){
        // TODO: implement
        return null;
    }
*/

}
