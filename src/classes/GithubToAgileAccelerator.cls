global with sharing class GithubToAgileAccelerator {
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

    global static Id addWorkRecord(Github.IssueCommentEvent evt){
        // look up the product tag in custom settings
        Github_Repositories__c repoSettings = Github_Repositories__c.getValues(evt.repository.name);
        System.assertNotEquals(null, evt.repository.id);
        // TODO: log an error if there's no matching repo
        System.assertEquals(String.valueOf(evt.repository.id), repoSettings.Github_Repository_Id__c, 'The github repository Id does not match the integration setting for repository name ' + evt.repository.name);

        // create the work record
        agf__ADM_Work__c work = new agf__ADM_Work__c (
            agf__Details__c = evt.issue.body,
            agf__Perforce_Status__c = 'Attached',
            agf__Product_Tag__c = repoSettings.Product_Tag__c,
            agf__Status__c = 'New - From Github',
            agf__Subject__c = evt.issue.title
        );
        insert work;

        GitHub_Link__c link = new GitHub_Link__c(
            GitHub_Id__c = evt.issue.id, 
            GitHub_Type__c = 'Issue',
            Work__c = work.Id
        );

        insert link;

        return link.Id;
    }

    global static Id attachToWorkRecord(Github.IssueCommentEvent evt, String workName){
        // try to find a work record with the matching name
        List<agf__ADM_Work__c> matchingWork = [ SELECT Id FROM agf__ADM_Work__c WHERE Name = :workName];
        if (matchingWork.size() > 0) {
            // if there's a match, make sure there's no existing github link
            List<GitHub_Link__c> matchingLinks = [ SELECT Id, GitHub_Id__c, Work__c, Work__r.Name 
                FROM GitHub_Link__c 
                WHERE Work__r.Name = :workName 
                AND GitHub_Id__c = :evt.issue.id ];
            if (matchingLinks.size() > 0) {
                return matchingLinks[0].Work__c;
            } else {
                // if the work matches but there's no link yet, create one
                GitHub_Link__c link = new GitHub_Link__c(
                    GitHub_Id__c = evt.issue.id, 
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

    global static Id attachToEpicRecord(Github.IssueCommentEvent evt, String epicName){
        // TODO: implement
        return null;
    }

    global static Id detachFromAllRecords(Github.IssueCommentEvent evt){
        List<GitHub_Link__c> linksToDelete = 
            [ SELECT Id FROM GitHub_Link__c WHERE GitHub_Id__c = :evt.issue.id ];
        if (!linksToDelete.isEmpty()) {
            delete linksToDelete;
        }
        return null;
    }
}