@isTest
private class GithubWebhookHandler_Test {

  @TestSetup
  static void setupTestData() {
     agf__ADM_Scrum_Team__c team = AATestData.scrumTeam;
     agf__ADM_Product_Tag__c tag = AATestData.productTag;

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
  }

  @isTest
  static void testIssuePost(){
    RestRequest req = new RestRequest(); // Build the REST Request for testing
    req.addHeader('X-GitHub-Event', 'issues');
    req.addHeader('Content-Type', 'application/json'); // Add a JSON Header as it is validated
    req.requestURI = GithubToAgileAccelerator.INSTANCE_URL + '/services/apexrest/github/webhook';
    req.httpMethod = 'POST';
    req.requestBody = Blob.valueof(GithubWebhookHandler_Mock.mockIssuesEvent('**lurch: add')); // Add JSON Message as a POST
    RestResponse res = new RestResponse();
    RestContext.request = req;
    RestContext.response = res;
    Test.startTest();
    GithubWebhookHandler.receiveEvent();
    Test.stopTest();
    system.assertEquals(1, [SELECT count() FROM Github_Request__c where Status__c = 'New']);
  }

  @isTest
  static void testIssueCommentPost(){
    RestRequest req = new RestRequest(); // Build the REST Request for testing
    req.addHeader('X-GitHub-Event', 'issue_comment');
    req.addHeader('Content-Type', 'application/json'); // Add a JSON Header as it is validated
    req.requestURI = GithubToAgileAccelerator.INSTANCE_URL + '/services/apexrest/github/webhook';
    req.httpMethod = 'POST';
    req.requestBody = Blob.valueof(GithubWebhookHandler_Mock.mockIssueCommentEvent('**lurch: add')); // Add JSON Message as a POST
    RestResponse res = new RestResponse();
    RestContext.request = req;
    RestContext.response = res;
    Test.startTest();
    GithubWebhookHandler.receiveEvent();
    Test.stopTest();
    system.assertEquals(1, [SELECT count() FROM Github_Request__c where Status__c = 'New']);
  }

  @isTest
  static void testPullRequestPost(){
    RestRequest req = new RestRequest(); // Build the REST Request for testing
    req.addHeader('X-GitHub-Event', 'pull_request');
    req.addHeader('Content-Type', 'application/json'); // Add a JSON Header as it is validated
    req.requestURI = GithubToAgileAccelerator.INSTANCE_URL + '/services/apexrest/github/webhook';
    req.httpMethod = 'POST';
    req.requestBody = Blob.valueof(GithubWebhookHandler_Mock.mockPullRequestEvent('**lurch: add')); // Add JSON Message as a POST
    RestResponse res = new RestResponse();
    RestContext.request = req;
    RestContext.response = res;
    Test.startTest();
    GithubWebhookHandler.receiveEvent();
    Test.stopTest();
    system.assertEquals(1, [SELECT count() FROM Github_Request__c where Status__c = 'New']);
  }

  @isTest
  static void testCommentOnExistingIssue(){
    agf__ADM_Work__c work = AATestData.work;

    Github_Link__c gl = new Github_Link__c(
      Work__c = work.id,
      Github_Unique_Id__c = 'public-repo_2'
    );
    insert gl;

    RestRequest req = new RestRequest(); // Build the REST Request for testing
    req.addHeader('X-GitHub-Event', 'issue_comment');
    req.addHeader('Content-Type', 'application/json'); // Add a JSON Header as it is validated
    req.requestURI = GithubToAgileAccelerator.INSTANCE_URL + '/services/apexrest/github/webhook';
    req.httpMethod = 'POST';
    req.requestBody = Blob.valueof(GithubWebhookHandler_Mock.mockIssueCommentEvent('a random comment')); // Add JSON Message as a POST
    RestResponse res = new RestResponse();
    RestContext.request = req;
    RestContext.response = res;
    Test.startTest();
    GithubWebhookHandler.receiveEvent();
    Test.stopTest();
    system.assertEquals(1, [SELECT count() FROM Github_Request__c where Status__c = 'New' AND Action__c = 'comment']);
  }

  @isTest
  static void testInvalidLurchCommand(){
    RestRequest req = new RestRequest(); // Build the REST Request for testing
    req.addHeader('X-GitHub-Event', 'issue_comment');
    req.addHeader('Content-Type', 'application/json'); // Add a JSON Header as it is validated
    req.requestURI = GithubToAgileAccelerator.INSTANCE_URL + '/services/apexrest/github/webhook';
    req.httpMethod = 'POST';
    req.requestBody = Blob.valueof(GithubWebhookHandler_Mock.mockIssueCommentEvent('**lurch: garbage')); // Add JSON Message as a POST
    RestResponse res = new RestResponse();
    RestContext.request = req;
    RestContext.response = res;
    Test.startTest();
    GithubWebhookHandler.receiveEvent();
    Test.stopTest();
    system.assertEquals(0, [SELECT count() FROM Github_Request__c where Status__c = 'New']);
  }
}
