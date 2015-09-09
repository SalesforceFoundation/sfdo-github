@isTest
global class GithubMock implements HttpCalloutMock {

    public String org {get; set;}
    public String repo {get; set;}
    public String client {get; set;}
    public Integer subject {get; set;}
    public Map<String, String> query {get; set;}
    public String method {get; set;}

    global HTTPResponse respond(HTTPRequest req) {
        String endpoint = req.getEndpoint();

        query = new Map<String, String>();

        String path = endpoint.replace('https://api.github.com/repos/', '');

        if (endpoint.contains('?')) {
            path = path.substring(0, path.indexOf('?'));

            String queryString = endpoint.substring(endpoint.indexOf('?')+1, endpoint.length());
            List<String> queryParts = queryString.split('&');
            if (!queryParts.isEmpty()) {
                for (String part : queryParts) {
                    List<String> split = part.split('=');
                    query.put(split[0], split[1]);
                }
            }
        }
        List<String> parts = path.split('/');

        org = parts[0];
        repo = parts[1];

        if (parts.size() > 2) {
            client = parts[2];
        }

        if (parts.size() > 3) {
            subject = Integer.valueOf(parts[3]);
        }

        method = req.getMethod();

        if (endpoint.contains('_HttpMethod=PATCH') && method == 'POST') {
            method = 'PATCH';
        }

        /* Milestones */
        if (client == 'milestones') {

            if (method == 'GET') {
                if (subject == null) {
                    return getMilestones(endpoint);
                } else {
                    return getMilestone();
                }
            }

            if (method == 'POST') {
                return createMilestone(req.getBody());
            }

            if (method == 'PATCH') {
                return updateItem(req.getBody());
            }

        }

        /* Hooks */
        if (client == 'hooks') {

            if (method == 'GET') {
                if (subject == null) {
                    return getHooks(endpoint);
                } else {
                    return getHook();
                }
            }

            if (method == 'POST') {
                return createHook(req.getBody());
            }

            if (method == 'PATCH') {
                return updateItem(req.getBody());
            }

        }

        /* Issues */
        if (client == 'issues') {

            if (method == 'GET') {
                if (subject == null) {
                    return getIssues();
                } else {
                    return getIssue();
                }
            }

            if (method == 'POST') {
                return createIssue(req.getBody());
            }

            if (method == 'PATCH') {
                return updateItem(req.getBody());
            }

        }

        if (req.getMethod() == 'DELETE') {
            return deleteItem();
        }

        return baseResponse();
    }

    global HttpResponse getMilestones(String url) {
        HttpResponse res = baseResponse();
        List<Github.Milestone> milestones = new List<Github.Milestone>();
        Integer page = 1;

        if (query.keySet().contains('page')) {
            page = Integer.valueOf(query.get('page'));
        }

        String link = '';
        if (page == 1) {
            link += '<https://api.github.com/repos/org/next/milestones?page=2>; rel="next"';
            link += ', <https://api.github.com/repos/org/last/milestones?page=4>; rel="last"';
        } else if (page == 2) {
            link += '<https://api.github.com/repos/org/next/milestones?page=3>; rel="next"';
            link += ', <https://api.github.com/repos/org/next/milestones?page=1>; rel="prev"';
            link += ', <https://api.github.com/repos/org/last/milestones?page=4>; rel="last"';
            link += ', <https://api.github.com/repos/org/last/milestones?page=1>; rel="first"';
        } else if (page == 3) {
            link += '<https://api.github.com/repos/org/next/milestones?page=4>; rel="next"';
            link += ', <https://api.github.com/repos/org/next/milestones?page=2>; rel="prev"';
            link += ', <https://api.github.com/repos/org/last/milestones?page=4>; rel="last"';
            link += ', <https://api.github.com/repos/org/last/milestones?page=1>; rel="first"';
        } else if (page == 4) {
            link += '<https://api.github.com/repos/org/prev/milestones?page=3>; rel="prev"';
            link += ', <https://api.github.com/repos/org/first/milestones?page=1>; rel="first"';
        }

        res.setHeader('Link', link);

        milestones.add(baseMilestone(page));

        res.setBody(JSON.serialize(milestones));
        return res;
    }


    global HttpResponse getMilestone() {
        HttpResponse res = baseResponse();
        res.setHeader('Link', '');

        res.setBody(JSON.serialize(baseMilestone(1)));
        return res;
    }

    global HttpResponse createMilestone(String body) {
        HttpResponse res = baseResponse();

        Github.Milestone milestone = (Github.Milestone) JSON.deserialize(body, Github.Milestone.class);
        milestone.num = 2;

        res.setBody(JSON.serialize(milestone));
        return res;
    }

    global HttpResponse updateMilestone(String body) {
        HttpResponse res = baseResponse();

        res.setBody(body);
        return res;
    }

    /* Issue */

    global HttpResponse getIssues() {
        HttpResponse res = baseResponse();
        Integer page = 1;

        if (query.keySet().contains('page')) {
            page = Integer.valueOf(query.get('page'));
        }

        String link = '';
        if (page == 1) {
            link += '<https://api.github.com/repos/org/next/issues?page=2>; rel="next"';
            link += ', <https://api.github.com/repos/org/last/issues?page=4>; rel="last"';
        } else if (page == 2) {
            link += '<https://api.github.com/repos/org/next/issues?page=3>; rel="next"';
            link += ', <https://api.github.com/repos/org/next/issues?page=1>; rel="prev"';
            link += ', <https://api.github.com/repos/org/last/issues?page=4>; rel="last"';
            link += ', <https://api.github.com/repos/org/last/issues?page=1>; rel="first"';
        } else if (page == 3) {
            link += '<https://api.github.com/repos/org/next/issues?page=4>; rel="next"';
            link += ', <https://api.github.com/repos/org/next/issues?page=2>; rel="prev"';
            link += ', <https://api.github.com/repos/org/last/issues?page=4>; rel="last"';
            link += ', <https://api.github.com/repos/org/last/issues?page=1>; rel="first"';
        } else if (page == 4) {
            link += '<https://api.github.com/repos/org/prev/issues?page=3>; rel="prev"';
            link += ', <https://api.github.com/repos/org/first/issues?page=1>; rel="first"';
        }
        res.setHeader('Link', link);

        List<Github.Issue> issues = new List<Github.Issue>();

        issues.add(baseIssue(page));

        res.setBody(JSON.serialize(issues));
        return res;
    }


    global HttpResponse getIssue() {
        HttpResponse res = baseResponse();

        res.setBody(JSON.serialize(baseIssue(1)));
        return res;
    }

    global HttpResponse createIssue(String body) {
        HttpResponse res = baseResponse();

        Github.Issue issue = (Github.Issue) JSON.deserialize(body, Github.Issue.class);
        issue.num = 2;

        res.setBody(JSON.serialize(issue));
        return res;
    }

    global HttpResponse updateItem(String body) {
        HttpResponse res = baseResponse();

        Map<String, Object> issue = (Map<String, Object>) JSON.deserializeUntyped(body);
        issue.remove('milestone');
        issue.remove('assignee');

        res.setBody(JSON.serialize(issue));
        return res;
    }

    global HttpResponse deleteItem() {
        HttpResponse res = baseResponse();
        res.setHeader('Link', '');
        return res;
    }

    global HttpResponse getHook() {
        HttpResponse res = baseResponse();
        res.setHeader('Link', '');

        res.setBody(JSON.serialize(baseHook(1)));
        return res;
    }

    global HttpResponse getHooks(String endpoint) {
      HttpResponse res = baseResponse();
      Integer page = 1;

      if (query.keySet().contains('page')) {
          page = Integer.valueOf(query.get('page'));
      }

      String link = '';
      if (page == 1) {
          link += '<https://api.github.com/repos/org/next/issues?page=2>; rel="next"';
          link += ', <https://api.github.com/repos/org/last/issues?page=4>; rel="last"';
      } else if (page == 2) {
          link += '<https://api.github.com/repos/org/next/issues?page=3>; rel="next"';
          link += ', <https://api.github.com/repos/org/next/issues?page=1>; rel="prev"';
          link += ', <https://api.github.com/repos/org/last/issues?page=4>; rel="last"';
          link += ', <https://api.github.com/repos/org/last/issues?page=1>; rel="first"';
      } else if (page == 3) {
          link += '<https://api.github.com/repos/org/next/issues?page=4>; rel="next"';
          link += ', <https://api.github.com/repos/org/next/issues?page=2>; rel="prev"';
          link += ', <https://api.github.com/repos/org/last/issues?page=4>; rel="last"';
          link += ', <https://api.github.com/repos/org/last/issues?page=1>; rel="first"';
      } else if (page == 4) {
          link += '<https://api.github.com/repos/org/prev/issues?page=3>; rel="prev"';
          link += ', <https://api.github.com/repos/org/first/issues?page=1>; rel="first"';
      }
      res.setHeader('Link', link);

      List<Github.Hook> hooks = new List<Github.Hook>();

      hooks.add(baseHook(page));

      res.setBody(JSON.serialize(hooks));
      return res;
    }

    global HttpResponse createHook(String body) {
        HttpResponse res = baseResponse();

        Github.Hook hook = (Github.Hook) JSON.deserialize(body, Github.Hook.class);

        res.setBody(JSON.serialize(hook));
        return res;
    }

    global HttpResponse updateHook(String body) {
        HttpResponse res = baseResponse();
        res.setBody(body);
        return res;
    }

    private HttpResponse baseResponse() {
        HttpResponse res = new HttpResponse();
        res.setStatus('OK');
        res.setStatusCode(200);
        res.setHeader('X-RateLimit-Limit', '5000');
        res.setHeader('X-RateLimit-Remaining', '4999');
        return res;
    }

    private Github.Milestone baseMilestone(Integer num) {
        Github.Milestone milestone = new Github.Milestone();
        milestone.url = 'https://api.github.com/repos/octocat/Hello-World/milestones/1';
        milestone.num = num;
        milestone.state = 'open';
        milestone.title = 'v0.1.0-beta1';
        milestone.description = 'We release a beta';
        milestone.open_issues = 4;
        milestone.closed_issues = 8;

        Github.User creator = new Github.User();
        creator.login = 'foo';
        milestone.creator = creator;

        return milestone;
    }

    private Github.Hook baseHook(Integer num){
        Github.Hook hook = new Github.Hook();
        hook.url = 'https://api.github.com/repos/octocat/Hello-World/hooks/1';
        hook.name = 'captain';
        hook.events = new List<String>();
        hook.active = true;
        hook.config = new Map<String, String>();
        return hook;
    }

    private Github.Issue baseIssue(Integer num) {
        Github.Issue issue = new Github.Issue();
        issue.url = 'https://api.github.com/repos/octocat/Hello-World/issues/1';
        issue.num = num;
        issue.state = 'open';
        issue.title = 'A major issue';
        issue.body = 'We release a beta';

        issue.user = new Github.User();
        issue.user.login = 'foo';

        issue.labels = new List<Github.Label>();

        Github.Label label = new Github.label();
        label.url = 'https://api.github.com/repos/octocat/Hello-World/issues/1';
        label.name = 'Super Important';
        label.color = '#000000';

        issue.labels.add(label);

        return issue;
    }
}
