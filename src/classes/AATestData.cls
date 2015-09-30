@isTest
public class AATestData {

    public static agf__ADM_Scrum_Team__c scrumTeam {
        get {
            if (scrumTeam == null) {
                List<agf__ADM_Scrum_Team__c> teams =
                    [ SELECT Id, Name, agf__Cloud__c
                        FROM agf__ADM_Scrum_Team__c
                        WHERE Name = 'Enterprise Systems' AND
                        agf__Cloud__c = 'Department Z' ];
                if (teams.size() > 0) {
                    scrumTeam = teams[0];
                } else {
                    scrumTeam = new agf__ADM_Scrum_Team__c (
                        Name = 'Enterprise Systems',
                        agf__Cloud__c = 'Department Z'
                    );
                    insert scrumTeam;
                }
            }
            return scrumTeam;
        }
        set;
    }

    public static agf__ADM_Product_Tag__c productTag {
        get {
            if (productTag == null) {
                List<agf__ADM_Product_Tag__c> tags =
                    [ SELECT Id, Name, agf__Team__c
                        FROM agf__ADM_Product_Tag__c
                        WHERE Name = 'Fake Tag' AND
                        agf__Team__c = :scrumTeam.Id ];
                if (tags.size() > 0) {
                    productTag = tags[0];
                } else {
                    productTag = new agf__ADM_Product_Tag__c(
                        Name = 'Fake Tag',
                        agf__Team__c = scrumTeam.Id
                    );
                    insert productTag;
                }
            }
            return productTag;
        }
        set;
    }

    public static agf__ADM_Work__c work {
        get {
            if (work == null) {
                List<agf__ADM_Work__c> workRecords =
                    [ SELECT Id, Name, agf__Details__c, agf__Product_Tag__c, agf__Status__c, agf__Subject__c
                        FROM agf__ADM_Work__c
                        WHERE agf__Product_Tag__c = :productTag.Id
                        AND agf__Subject__c = 'Do stuff' ];

                if (workRecords.size() > 0) {
                    work = workRecords[0];
                } else {
                    work = new agf__ADM_Work__c (
                        agf__Details__c = 'Do some really really ridiculously important stuff.',
                        agf__Product_Tag__c = productTag.Id,
                        agf__Status__c = 'New',
                        agf__Subject__c = 'Do stuff'
                    );
                    insert work;
                    // query so we have name
                    workRecords =
                        [ SELECT Id, Name, agf__Details__c, agf__Product_Tag__c, agf__Status__c, agf__Subject__c
                            FROM agf__ADM_Work__c
                            WHERE agf__Product_Tag__c = :productTag.Id
                            AND agf__Subject__c = 'Do stuff' ];
                    work = workRecords[0];
                }
            }
            return work;
        }
        set;
    }
}
