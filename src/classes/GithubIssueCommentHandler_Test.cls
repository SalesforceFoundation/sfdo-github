@isTest
private class GithubIssueCommentHandler_Test {
    
    @isTest static void testParseAdd() {
        GithubToAgileAccelerator.Action action = GithubToAgileAccelerator.parseAction('**lurch:add Do some stuff');
        System.assertEquals('add', action.type);

        action = GithubToAgileAccelerator.parseAction('**lurch:ADD Do some stuff');
        System.assertEquals('ADD', action.type);
        System.assertEquals('Do some stuff', action.body);

    }

    @isTest static void testParseAttachWork() {
        GithubToAgileAccelerator.Action action = GithubToAgileAccelerator.parseAction('**lurch:attach W-12345 ');
        System.assertEquals('attach', action.type);
        System.assertEquals('W-12345', action.target);

        action = GithubToAgileAccelerator.parseAction('**lurch:attach w-12345 ');
        System.assertEquals('attach', action.type);
        System.assertEquals('w-12345', action.target);
    }
    
}