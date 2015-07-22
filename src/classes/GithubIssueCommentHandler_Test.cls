@isTest
private class GithubIssueCommentHandler_Test {
	
	@isTest static void testParseAdd() {
		GithubIssueCommentHandler.CommentAction action = GithubIssueCommentHandler.parseAction('**lurch:add Do some stuff');
        System.assertEquals('add', action.type);

        action = GithubIssueCommentHandler.parseAction('**lurch:ADD Do some stuff');
        System.assertEquals('ADD', action.type);
        System.assertEquals('Do some stuff', action.body);

	}

    @isTest static void testParseAttachWork() {
        GithubIssueCommentHandler.CommentAction action = GithubIssueCommentHandler.parseAction('**lurch:attach W-12345 ');
        System.assertEquals('attach', action.type);
        System.assertEquals('W-12345', action.recordName);

        action = GithubIssueCommentHandler.parseAction('**lurch:attach w-12345 ');
        System.assertEquals('attach', action.type);
        System.assertEquals('w-12345', action.recordName);
    }
	
}