@isTest
private class GithubToAgileAccelerator_Test {

  @TestSetup
  static void setupTestData() {
     agf__ADM_Scrum_Team__c team = AATestData.scrumTeam;
     agf__ADM_Product_Tag__c tag = AATestData.productTag;
     agf__ADM_Work__c work = AATestData.work;

    Github_Integration_Users__c giu = new Github_Integration_Users__c(
      Name = 'User1',
      Github_Username__c = 'baxterthehacker'
    );
    insert giu;

    Github_Repositories__c gr = new Github_Repositories__c(
      Name = 'public-repo',
      Github_Repository_Id__c = '35129377',
      Token__c = '1234567890',
      Product_Tag__c = AATestData.productTag.Id
    );
    insert gr;

    Github_Request__c gr_add = new Github_Request__c(
      Body__c = 'The body of my issue comment **lurch: add',
      Title__c = 'The title of my issue',
      Github_Username__c = 'theusername',
      Github_Record_Id__c = '137538186',
      Github_Record_URL__c = 'https://github.com/SalesforceFoundation/sfdo-github/issues/16#issuecomment-137538186',
      Github_Repository__c = 'public-repo',
      Github_Record_Number__c = '16',
      Action__c = 'add',
      Status__c = 'New'
    );
    insert gr_add;

    Github_Request__c gr_attach = new Github_Request__c(
      Body__c = 'The body of my issue comment **lurch: attach ' + work.Name,
      Title__c = 'The title of my issue',
      Github_Username__c = 'theusername',
      Github_Record_Id__c = '137538186',
      Github_Record_URL__c = 'https://github.com/SalesforceFoundation/sfdo-github/issues/16#issuecomment-137538186',
      Github_Repository__c = 'public-repo',
      Github_Record_Number__c = '16',
      Action__c = 'attach',
      Status__c = 'New',
      Target__c = work.id
    );
    insert gr_attach;

    Github_Request__c gr_detach = new Github_Request__c(
      Body__c = 'The body of my issue comment **lurch: detach',
      Title__c = 'The title of my issue',
      Github_Username__c = 'theusername',
      Github_Record_Id__c = '137538186',
      Github_Record_URL__c = 'https://github.com/SalesforceFoundation/sfdo-github/issues/16#issuecomment-137538186',
      Github_Repository__c = 'public-repo',
      Github_Record_Number__c = '16',
      Action__c = 'detach',
      Status__c = 'New',
      Target__c = work.id
    );
    insert gr_detach;

    Github_Request__c gr_comment = new Github_Request__c(
      Body__c = 'The body of my issue comment',
      Title__c = 'The title of my issue',
      Github_Username__c = 'theusername',
      Github_Record_Id__c = '137538186',
      Github_Record_URL__c = 'https://github.com/SalesforceFoundation/sfdo-github/issues/16#issuecomment-137538186',
      Github_Repository__c = 'public-repo',
      Github_Record_Number__c = '16',
      Action__c = 'comment',
      Status__c = 'New',
      Target__c = work.Id
    );
    insert gr_comment;
  }

  @isTest
  static void testUtils(){
    System.assertNotEquals(null, GithubToAgileAccelerator.INSTANCE_URL);
    System.assert(GithubToAgileAccelerator.isAuthorizedUser('baxterthehacker'));
    System.assert(GithubToAgileAccelerator.isRecognizedCommand('add'));
    System.assert(GithubToAgileAccelerator.isMappedRepository('public-repo'));
    Github_Request__c gr = [SELECT id, Github_Repository__c, Github_Record_Number__c from Github_Request__c where Action__c = 'add'];
    System.assertEquals('public-repo_16', GithubToAgileAccelerator.getUniqueId(gr));
  }

  @isTest
  static void testActionParsing(){
    GithubToAgileAccelerator.Action a = GithubToAgileAccelerator.parseAction('dlk;jaf;slkjf;skljfas;ljkd **lurch: attach w-12345');
    System.assertEquals(a.type, 'attach');
    System.assertEquals(a.target, 'w-12345');
  }

  @isTest
  static void testAddWorkRecords(){
    List<Github_Request__c> glist = [SELECT id, Status__c, Github_Unique_Id__c, Title__c, Target__c, Github_Repository__c, Body__c, Github_Record_Type__c, Github_Record_URL__c from Github_Request__c where Action__c = 'add' limit 1];
    Test.startTest();
    glist = GithubToAgileAccelerator.addWorkRecords(glist);
    Test.stopTest();
    System.assertEquals('Processed', glist[0].Status__c);
    System.assertEquals(1, [SELECT count() FROM Github_Link__c]);
  }

  @isTest
  static void testAttachWorkRecords(){
    List<Github_Request__c> glist = [SELECT id, Status__c, Github_Unique_Id__c, Title__c, Target__c, Github_Repository__c, Body__c, Github_Record_Type__c, Github_Record_URL__c from Github_Request__c where Action__c = 'attach' limit 1];
    Test.startTest();
    glist = GithubToAgileAccelerator.attachWorkToRecords(glist);
    Test.stopTest();
    System.assertEquals('Processed', glist[0].Status__c);
  }

  @isTest
  static void testDetachWorkRecords(){
    agf__ADM_Work__c w = [SELECT id, Name from agf__ADM_Work__c LIMIT 1];
    List<Github_Request__c> glist = [SELECT id, Status__c, Github_Unique_Id__c, Title__c, Target__c, Github_Repository__c, Body__c, Github_Record_Type__c, Github_Record_URL__c from Github_Request__c where Action__c = 'detach' limit 1];
    Github_Link__c gl = new Github_Link__c(
      Work__c = w.id,
      Github_Unique_Id__c = 'public-repo_16'
    );
    insert gl;
    Test.startTest();
    glist = GithubToAgileAccelerator.detachFromAllRecords(glist);
    Test.stopTest();
    System.assertEquals('Processed', glist[0].Status__c);
    System.assertEquals(0, [SELECT count() FROM Github_Link__c]);
  }

  @isTest
  static void testPostComment(){
    List<Github_Request__c> glist = [SELECT id, Status__c, Github_Unique_Id__c, Action__c, Title__c, Target__c, Github_Username__c, Github_Repository__c, Body__c, Github_Record_Type__c, Github_Record_URL__c from Github_Request__c where Action__c = 'comment' limit 1];
    Test.startTest();
    glist = GithubToAgileAccelerator.handleComments(glist);
    Test.stopTest();
    System.assertEquals('Processed', glist[0].Status__c);
    System.assertEquals(1, [SELECT count() FROM FeedItem WHERE ParentId = :glist[0].Target__c]);
    System.assertEquals('@theusername: The body of my issue comment', [SELECT Body FROM FeedItem WHERE ParentId = :glist[0].Target__c].Body);
  }
}
