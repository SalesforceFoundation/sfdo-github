@isTest
private class GithubRequestHandler_TEST {

  @TestSetup
  static void setupTestData() {
     agf__ADM_Scrum_Team__c team = AATestData.scrumTeam;
     agf__ADM_Product_Tag__c tag = AATestData.productTag;

    Github_Integration_Users__c giu = new Github_Integration_Users__c(
      Name = 'User1',
      Github_Username__c = 'theusername'
    );
    insert giu;

    Github_Repositories__c gr = new Github_Repositories__c(
      Name = 'sfdo-github',
      Github_Repository_Id__c = 'sfdo-github',
      Token__c = '1234567890',
      Product_Tag__c = tag.id
    );
    insert gr;
  }

  //add, attach, remove, comment
  @isTest
  static void testAddProcess() {

    Github_Request__c gr_add = new Github_Request__c(
      Body__c = 'The body of my issue comment **lurch: add',
      Title__c = 'The title of my issue',
      Github_Username__c = 'theusername',
      Github_Record_Id__c = '137538186',
      Github_Record_URL__c = 'https://github.com/SalesforceFoundation/sfdo-github/issues/16#issuecomment-137538186',
      Github_Repository__c = 'sfdo-github',
      Github_Record_Number__c = '16',
      Action__c = 'add',
      Status__c = 'New'
    );
    insert gr_add;

    Github_Request__c gr_add2 = new Github_Request__c(
      Body__c = 'The body of my issue comment2 **lurch: add',
      Title__c = 'The title of my issue2',
      Github_Username__c = 'theusername',
      Github_Record_Id__c = '1375332326',
      Github_Record_URL__c = 'https://github.com/SalesforceFoundation/sfdo-github/issues/17#issuecomment-137538186',
      Github_Repository__c = 'sfdo-github',
      Github_Record_Number__c = '17',
      Action__c = 'add',
      Status__c = 'New'
    );
    insert gr_add2;

    Test.startTest();
    GithubRequestHandler grh = new GithubRequestHandler();
    grh.processRequests();
    Test.stopTest();

    Github_Request__c gr = [ SELECT Id, Body__c, Title__c, Comment__c, Action__c, Target__c,
        Github_Record_Id__c, Github_Record_Type__c, Github_Record_URL__c,
        Github_Repository__c, Github_Username__c, Status__c, Github_Unique_Id__c,
        Github_Record_Number__c
        FROM Github_Request__c
        WHERE Github_Record_URL__c = 'https://github.com/SalesforceFoundation/sfdo-github/issues/16#issuecomment-137538186'
        AND
        Action__c = 'add'
        ORDER BY CreatedDate
    ];

    System.assertEquals('Processed', gr.Status__c);
    System.assertNotEquals(gr.Target__c, null);
    Github_Link__c gl = [SELECT Id, Work__c, Github_Unique_Id__c from Github_Link__c where Github_Unique_Id__c = 'sfdo-github_16' limit 1];
    System.assertEquals(gl.Github_Unique_Id__c, gr.Github_Unique_Id__c);
    System.assertNotEquals(gl.Work__c, null);
  }

  @isTest
  static void testRemoveProcess() {

    Github_Request__c gr_remove = new Github_Request__c(
      Body__c = 'The body of my issue comment **lurch: remove',
      Title__c = 'The title of my issue',
      Github_Username__c = 'theusername',
      Github_Record_Id__c = '137538186',
      Github_Record_URL__c = 'https://github.com/SalesforceFoundation/sfdo-github/issues/16#issuecomment-137538186',
      Github_Repository__c = 'sfdo-github',
      Github_Record_Number__c = '16',
      Action__c = 'remove',
      Status__c = 'New'
    );
    insert gr_remove;

    agf__ADM_Work__c work = AATestData.work;

    Github_Link__c gl = new Github_Link__c(
      Work__c = work.id,
      Github_Unique_Id__c = 'sfdo-github_16'
    );
    insert gl;

    Test.startTest();
    GithubRequestHandler grh = new GithubRequestHandler();
    grh.processRequests();
    Test.stopTest();

    System.assertEquals(0, [SELECT count() FROM Github_Link__c WHERE Work__c = :work.id]);
    System.assertEquals('Processed', [SELECT Status__c from Github_Request__c where Id = :gr_remove.id].Status__c);
  }

  @isTest
  static void testAttachProcess() {

    agf__ADM_Work__c work = AATestData.work;
    String wname = [SELECT Name from agf__ADM_Work__c where id = :work.id].Name;

    Github_Request__c gr_attach = new Github_Request__c(
      Body__c = 'The body of my issue comment **lurch: attach ' + wname,
      Title__c = 'The title of my issue',
      Github_Username__c = 'theusername',
      Github_Record_Id__c = '137538186',
      Github_Record_URL__c = 'https://github.com/SalesforceFoundation/sfdo-github/issues/16#issuecomment-137538186',
      Github_Repository__c = 'sfdo-github',
      Github_Record_Number__c = '16',
      Action__c = 'attach',
      Status__c = 'New',
      Target__c = wname
    );
    insert gr_attach;

    Test.startTest();
    GithubRequestHandler grh = new GithubRequestHandler();
    grh.processRequests();
    Test.stopTest();

    System.assertEquals(1, [SELECT count() FROM Github_Link__c WHERE Work__c = :work.id]);
    System.assertEquals('Processed', [SELECT Status__c from Github_Request__c where Id = :gr_attach.id].Status__c);
  }

  @isTest
  static void testCommentProcess() {
    agf__ADM_Work__c work = AATestData.work;

    Github_Request__c gr_comment = new Github_Request__c(
      Body__c = 'The body of my issue comment',
      Title__c = 'The title of my issue',
      Github_Username__c = 'theusername',
      Github_Record_Id__c = '137538186',
      Github_Record_URL__c = 'https://github.com/SalesforceFoundation/sfdo-github/issues/16#issuecomment-137538186',
      Github_Repository__c = 'sfdo-github',
      Github_Record_Number__c = '16',
      Action__c = 'comment',
      Status__c = 'New',
      Target__c = work.id
    );
    insert gr_comment;

    Github_Link__c gl = new Github_Link__c(
      Work__c = work.id,
      Github_Unique_Id__c = 'sfdo-github_16'
    );
    insert gl;

    Test.startTest();
    GithubRequestHandler grh = new GithubRequestHandler();
    grh.processRequests();
    Test.stopTest();

    FeedItem fi = [SELECT id, Body from FeedItem where ParentId = :work.id ORDER BY CreatedDate desc LIMIT 1];

    System.assertEquals('@theusername: ' + gr_comment.Body__c, fi.Body);
  }

  @isTest
  static void testExecuteMethod() {
    String CRON_EXP = '0 0 0 15 3 ? 2022';
    Test.startTest();
    String jobId = System.schedule('ScheduleApexClassTest', CRON_EXP, new GithubRequestHandler());
    Test.stopTest();
  }
}
