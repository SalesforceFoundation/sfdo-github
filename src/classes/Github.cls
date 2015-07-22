/**
* @author Ryan Foster, Salesforce Foundation
* @date 2015
*
* @group Github
*
* @description Github API Client. Currently supports milestones, issues and
* hooks (limited) using basic oath.
*/
global with sharing class Github {

    /**
    * @description The Github user or organization to connect to. This is the
    * second part of a repository URL: https://www.github.com/<User>/<Repository>
    */
    global String organization { get; set; }

    /**
    * @description The repository to connect to. This is the third part of the
    * repository URL: https://www.github.com/<User>/<Repository>
    */
    global String repository { get; set; }

    /**
    * @description A valid Github authentication Token. Right now this cilent
    * only supports "Personal Access Tokens" which can be generated using the
    * Github settings: https://github.com/settings/applications
    */
    global String token { get; set; }

    /**
    * @description The authentication type to use. Currently only supports
    * ':x-oauth-basic'
    */
    global String authenticationType { get; set; } { authenticationType = ':x-oauth-basic'; }

    /**
    * @description The status of the last request made.
    */
    global String lastStatus { get; private set; }

    /**
    * @description The status code of the last request made. For example:
    * 200.
    */
    global Integer lastStatusCode { get; private set; }

    /**
    * @description Github's APIs have a limit on the number of requests that
    * can be made (generally 4000). After the first successful request the
    * limit is stored here.
    */
    global Integer rateLimit { get; private set; }

    /**
    * @description The remaining number of requests that can be made before the
    * rate limit is exceeded.
    */
    global Integer rateLimitRemaining { get; private set; } { rateLimitRemaining = 1; }

    global class User {
        global String login { get; set; }
        global Integer id { get; set; }
        global String avatar_url { get; set; }
        global String gravatar_id { get; set; }
        global String url { get; set; }
        global String html_url { get; set; }
        global String followers_url { get; set; }
        global String following_url { get; set; }
        global String gists_url { get; set; }
        global String starred_url { get; set; }
        global String subscriptions_url { get; set; }
        global String organizations_url { get; set; }
        global String repos_url { get; set; }
        global String events_url { get; set; }
        global String type { get; set; }
        global Boolean site_admin { get; set; }
    }

    global class Label {
        global String url { get; set; }
        global String name { get; set; }
        global String color { get; set; }
    }

    global class Milestone {
        global String url { get; set; }
        /**
        * @description number is shortened to num to avoid reserved word
        */
        global Integer num { get; set; }
        global String state { get; set; }
        global String title { get; set; }
        global String description { get; set; }
        global Integer open_issues { get; set; }
        global Integer closed_issues { get; set; }
        global Datetime created_at { get; set; }
        global Datetime updated_at { get; set; }
        global Datetime due_on { get; set; }

        global Github.User creator { get; set; }
    }

    global class PullRequest {
        global String url { get; set; }
        global String html_url { get; set; }
        global String diff_url { get; set; }
        global String patch_url { get; set; }
    }

    global class Issue {
        global String id { get; set; }
        global String url { get; set; }
        global String html_url { get; set; }

        /**
        * @description number is shortened to num to avoid reserved word
        */
        global Integer num { get; set; }
        global String state { get; set; }
        global String title { get; set; }
        global String body { get; set; }
        global String body_raw { get; set; }
        global String body_html { get; set; }
        global String body_text { get; set; }
        global Integer comments { get; set; }
        global Datetime closed_at { get; set; }
        global Datetime created_at { get; set; }
        global Datetime updated_at { get; set; }

        global String labels_url { get; set; }
        global String comments_url { get; set; }
        global String events_url { get; set; }

        global Github.User user { get; set; }

        global List<Github.Label> labels { get; set; }

        /**
        * @description As with milestone, this will be a full object only when retrieving
        * an issue, you must set assigneeUsername if you want to set the assigned
        * during a save/update
        */
        global Github.User assignee { get; set; }

        /**
        * @description Use assigneeUsername when you want to save/update the assignee
        */
        global String assigneeUsername { get; set; }

        /**
        * @description Milestone will be set when you retrieve a milestone from github,
        * do not use it when you want to save an issue and assign the milestone
        * as github expects the milestone attribute to be and Integer of the milestone
        * number when create new issues and updating existing issues.
        */
        global Github.Milestone milestone { get; set; }

        // Use milestoneNumber when saving issues
        global Integer milestoneNumber { get; set; }

        global Github.User closed_by { get; set; }

        global Github.Issue() {
            this.labels = new List<Github.Label>();
        }
    }

    global class Comment {
        global Integer id { get; set; }
        global String url { get; set; }
        global String html_url { get; set; }
        global String body { get; set; }
        global Github.User user { get; set; }
        global Datetime created_at { get; set; }
        global Datetime updated_at { get; set; }
    }

    global class Repository {
        global Integer id { get; set; }
        global String name { get; set; }
        global String full_name { get; set; }
        global String html_url { get; set; }
        global String description { get; set; }
        global Boolean fork { get; set; }
    }

    global class IssueEvent {
        global String action { get; set; }
        global Github.Issue issue { get; set; }
        global Github.Repository repository { get; set; }
    }

    global class IssueCommentEvent {
        global String action { get; set; }
        global Github.Issue issue { get; set; }
        global Github.Comment comment { get; set; } 
        global Github.Repository repository { get; set; } 
    }

    global class Hook {
        global String url { get; set; }
        global String name { get; set; }
        global List<String> events { get; set; }
        global Boolean active { get; set; }
        global Map<String, String> config { get; set; }
        global Integer id { get; set; }
    }

    /**
    * @description Instance of the MilestoneClient so that it is conveniently
    * accessible from the base clase: `git.milestones.get()`.
    */
    global Github.MilestoneClient milestones { get; set; }

    /**
    * @description Instance of the IssueClient so that it is conveniently
    * accessible from the base clase: `git.issues.get()`.
    */
    global Github.IssueClient issues { get; set; }

    /**
    * @description Instance of the HookClient so that it is conveniently
    * accessible from the base clase: `git.hooks.get()`.
    */
    global Github.HookClient hooks { get; set; }

    /**
    * @description Default instantiator.
    * @param organization the github organization or user to connect to
    * @param repo the repository under SalesforceFoundation to connect to
    * @param token the auth token to use when connecting
    */
    global Github(String organization, String repo, String token) {
        this.organization = organization;
        this.repository = repo;
        this.token = token;

        this.setup();
    }

    /**
    * @description Instantiator which will set the default organization of
    * 'SalesforceFoundation'.
    * @param repo the repository under SalesforceFoundation to connect to
    * @param token the auth token to use when connecting
    */
    global Github(String repo, String token) {
        this.organization = 'SalesforceFoundation';
        this.repository = repo;
        this.token = token;

        this.setup();
    }

    /**
    * @description Set the associated clients on the base instance.
    */
    global void setup() {
        this.milestones = new Github.MilestoneClient(this, 'milestones');
        this.issues = new Github.IssueClient(this, 'issues');
        this.hooks = new Github.HookClient(this);
    }

    /**
    * @description Base Class for tracking and making Github requests.
    */
    global class BaseResponse {
        global String url { get; set; }
        global String status { get; set; }
        global Integer statusCode { get; set; }
        global Integer rateLimit { get; set; }
        global Integer rateLimitRemaining { get; set; }

        global String next { get; set; }
        global String prev { get; set; }
        global String first { get; set; }
        global String last { get; set; }

        global Integer pageCount { get; set; }

        global String body { get; set; }

        /**
        * @description Sole constructor, processes the response from Github
        * and sets parameters accordingly.
        * @param response the HttpResponse to process
        */
        global BaseResponse(HttpResponse response) {
            this.status = response.getStatus();
            this.statusCode = response.getStatusCode();

            String rate = response.getHeader('X-RateLimit-Limit');
            if (rate != null) {
                this.rateLimit = Integer.valueOf(rate);
            }

            String remaining = response.getHeader('X-RateLimit-Remaining');
            if (remaining != null) {
                this.rateLimitRemaining = Integer.valueOf(remaining);
            }

            this.body =  Github.renameReserved(response.getBody());

            String link = response.getHeader('Link');
            if (link != null) {
                List<String> pairs = link.split(',');

                if (!pairs.isEmpty()) {
                    for (String pair : pairs) {
                        if (pair.contains('rel="next"')) {
                            this.next = Github.parseLinkUrl(pair);
                        } else if (pair.contains('rel="prev"')) {
                            this.prev = Github.parseLinkUrl(pair);
                        } else if (pair.contains('rel="last"')) {
                            this.last = Github.parseLinkUrl(pair);

                            String sub = this.last.split('page=')[1].split('&')[0];
                            try {
                                this.pageCount = Integer.valueOf(sub);
                            } catch(Exception e) {

                            }
                        } else if (pair.contains('rel="first"')) {
                            this.first = Github.parseLinkUrl(pair);
                        }
                    }
                }
            }
        }
    }

    /**
    * @description Base Class for Github clients, a loose "interface" and
    * starting point for creating new clients.
    */
    global abstract class BaseClient {
        global Github parent;
        global BaseResponse lastResponse { get; set; }
        global String endpoint { get; set; }
        global Integer perPage { get; set; } { perPage = 30; }

        global Boolean hasFirst {
            get {
                return this.lastResponse != null && this.lastResponse.first != null;
            }
        }
        global Boolean hasLast {
            get {
                return this.lastResponse != null && this.lastResponse.last != null;
            }
        }
        global Boolean hasNext {
            get {
                return this.lastResponse != null && this.lastResponse.next != null;
            }
        }
        global Boolean hasPrev {
            get {
                return this.lastResponse != null && this.lastResponse.prev != null;
            }
        }

        global BaseClient() {}

        global BaseClient(Github parent, String endpoint) {
            this.parent = parent;
            this.endpoint = endpoint;
        }

        global BaseResponse makeRequest(String ep, String method, String body) {
            String target = ep != null && ep != '' ? this.endpoint + '/' + ep : this.endpoint;
            if (ep != null && ep.startsWith('?')) {
                target = this.endpoint + ep;
            }
            String renamedBody = null;
            if (body != null) {
                renamedBody = renameReservedBack(body);
            }
            this.lastResponse = this.parent.makeRequest(target, method, renamedBody);
            return this.lastResponse;
        }

        global BaseResponse makeRequest(String method, String body) {
            return makeRequest(null, method, body);
        }

        global BaseResponse makeRequest(Integer num) {
            return makeRequest(String.valueOf(num), 'GET', null);
        }

        global BaseResponse makeRequest(String url) {
            this.lastResponse = this.parent.makeRequest(url);
            return this.lastResponse;
        }

        global BaseResponse makeRequest() {
            return this.makeRequest('GET', null);
        }

        global void paginate(String url) {
            this.makeRequest(url);
        }

    }

    /**
    * @description Client for Milestones.
    *
    * Use from an instance of the base `Github` class:
    *
    * Github git = new Github(repo, xxx-auth-token);
    *
    * Retrieve the first 30 Milestones:
    * git.milestones.get();
    *
    * Check if there are more Milestones:
    * if (git.milestones.hasNext) {}
    *
    * Get the next 30 Milestones:
    * git.milestones.next();
    *
    * Check if there is a previous page of Milestones:
    * if (git.milestones.hasPrev) {}
    *
    * Get the previous 30 Milestones:
    * git.milestones.prev();
    *
    * Get all Milestones:
    * git.milestones.all();
    *
    * Get a single Milestone by milestone num (Github id):
    * git.milestones.get(1);
    *
    * Create a new milestone:
    * git.milestones.create(milestone);
    *
    * Update a milestone that has a valid `num` (Github id):
    * git.milestones.put(milestone);
    *
    * Delete a milestone that has a valid `num` (Github id):
    * git.milestones.remove(milestone);
    *
    */
    global class MilestoneClient extends BaseClient {

        global MilestoneClient(Github parent, String endpoint) {
            this.parent = parent;
            this.endpoint = endpoint;
        }

        /**
         *   @param state: Either open, closed, or all
         *   @param sort: Either due_date or completeness
         *   @param direction: Either asc or desc
        */
        global List<Github.Milestone> get(String state, String sortBy, String direction, Integer perPage) {
            String query = Github.buildQueryString(new Map<String, String>{
                    'state' => state,
                    'sort' => sortBy,
                    'direction' => direction,
                    'per_page' => perPage != null ? String.valueOf(perPage) : null
                });

            this.makeRequest(query, 'GET', null);
            return (List<Github.Milestone>) JSON.deserialize(this.lastResponse.body, List<Github.Milestone>.class);
        }

        global List<Github.Milestone> get() {
            return get(null, null, null, null);
        }

        global Github.Milestone get(Integer num) {
            System.assert(num != null, 'Milestone number is required to get a Milestone.');
            this.makeRequest(num);
            return (Github.Milestone) JSON.deserialize(this.lastResponse.body, Github.Milestone.class);
        }

        global Github.Milestone create(Github.Milestone milestone) {
            milestone.due_on = offsetDate(milestone.due_on);
            this.makeRequest(String.valueOf(milestone.num), 'POST', JSON.serialize(milestone));
            return (Github.Milestone) JSON.deserialize(this.lastResponse.body, Github.Milestone.class);
        }

        global Github.Milestone put(Github.Milestone milestone) {
            milestone.due_on = offsetDate(milestone.due_on);
            this.makeRequest(String.valueOf(milestone.num), 'PATCH', JSON.serialize(milestone));
            return (Github.Milestone) JSON.deserialize(this.lastResponse.body, Github.Milestone.class);
        }

        global void remove(Github.Milestone milestone) {
            this.makeRequest(String.valueOf(milestone.num), 'DELETE', null);
        }

        global List<Github.Milestone> next() {
            this.paginate(this.lastResponse.next);
            return (List<Github.Milestone>) JSON.deserialize(this.lastResponse.body, List<Github.Milestone>.class);
        }

        global List<Github.Milestone> prev() {
            this.paginate(this.lastResponse.prev);
            return (List<Github.Milestone>) JSON.deserialize(this.lastResponse.body, List<Github.Milestone>.class);
        }

        global List<Github.Milestone> last() {
            this.paginate(this.lastResponse.last);
            return (List<Github.Milestone>) JSON.deserialize(this.lastResponse.body, List<Github.Milestone>.class);
        }

        global List<Github.Milestone> first() {
            this.paginate(this.lastResponse.first);
            return (List<Github.Milestone>) JSON.deserialize(this.lastResponse.body, List<Github.Milestone>.class);
        }

        global List<Github.Milestone> all() {
            List<Github.Milestone> milestones = this.get('all', null, null, 100);
            while (this.hasNext) {
                milestones.addAll(this.next());
            }
            return milestones;
        }

    }


    /**
    * @description Client for Issue.
    *
    * Use from an instance of the base `Github` class:
    *
    * Github git = new Client(repo, xxx-auth-token);
    *
    * Retrieve the first 30 Issues:
    * git.issues.get();
    *
    * Check if there are more Issues:
    * if (git.issues.hasNext) {}
    *
    * Get the next 30 Milestones:
    * git.issues.next();
    *
    * Check if there is a previous page of Issues:
    * if (git.issues.hasPrev) {}
    *
    * Get the previous 30 Issues:
    * git.issues.prev();
    *
    * Get all Issues:
    * git.issues.all();
    *
    * Get a single Issue by issue num (Github id):
    * git.issues.get(1);
    *
    * Create a new Issue:
    * git.issues.create(issue);
    *
    * Update an Issue that has a valid `num` (Github id):
    * git.issues.put(issue);
    *
    * Delete an Issue that has a valid `num` (Github id):
    * git.issues.remove(issue);
    *
    */
    global class IssueClient extends BaseClient {

        global IssueClient(Github parent, String endpoint) {
            this.parent = parent;
            this.endpoint = endpoint;
        }

        /**
        * @param filter string  Indicates which sorts of issues to return. Can be one of:
        *   - assigned: Issues assigned to you
        *   - created: Issues created by you
        *   - mentioned: Issues mentioning you
        *   - subscribed: Issues you’re subscribed to updates for
        *   - all: All issues the authenticated user can see, regardless of participation or creation
        *   - Default: all
        * @param state   string  Indicates the state of the issues to return. Can be either open, closed, or all. Default: open
        * @param labels  string  A list of comma separated label names. Example: bug,ui,@high
        * @param sort    string  What to sort results by. Can be either created, updated, comments. Default: created
        * @param direction   string  The direction of the sort. Can be either asc or desc. Default: desc
        * @param since   string  Only issues updated at or after this time are returned. This is a timestamp in ISO 8601 format: YYYY-MM-DDTHH:MM:SSZ.
        **/
        global List<Github.Issue> get(String filter, String state, String labels,
                String sortBy, String direction, String since, Integer perPage) {

            String query = buildQueryString(new Map<String, String>{
                'filter' => filter,
                'state' => state,
                'labels' => labels,
                'sort' => sortBy,
                'direction' => direction,
                'since' => since,
                'per_page' => perPage != null ? String.valueOf(perPage) : null
            });
            this.makeRequest(query, 'GET', null);
            return (List<Github.Issue>) JSON.deserialize(this.lastResponse.body, List<Github.Issue>.class);
        }

        global List<Github.Issue> get() {
            return this.get('all', null, null, null, null, null, null);
        }

        global Github.Issue get(Integer num) {
            System.assert(num != null, 'Issue number is required to get a Issue.');
            this.makeRequest(num);
            return (Github.Issue) JSON.deserialize(this.lastResponse.body, Github.Issue.class);
        }

        global Github.Issue create(Github.Issue issue) {
            this.makeRequest('POST', JSON.serialize(issue));
            return (Github.Issue) JSON.deserialize(this.lastResponse.body, Github.Issue.class);
        }

        global Github.Issue put(Github.Issue issue) {
            this.makeRequest(String.valueOf(issue.num), 'PATCH', JSON.serialize(issue));
            return (Github.Issue) JSON.deserialize(this.lastResponse.body, Github.Issue.class);
        }

        global void remove(Github.Issue issue) {
            this.makeRequest(String.valueOf(issue.num), 'DELETE', null);
        }

        global List<Github.Issue> next() {
            super.paginate(this.lastResponse.next);
            return (List<Github.Issue>) JSON.deserialize(this.lastResponse.body, List<Github.Issue>.class);
        }

        global List<Github.Issue> prev() {
            super.paginate(this.lastResponse.prev);
            return (List<Github.Issue>) JSON.deserialize(this.lastResponse.body, List<Github.Issue>.class);
        }

        global List<Github.Issue> last() {
            super.paginate(this.lastResponse.last);
            return (List<Github.Issue>) JSON.deserialize(this.lastResponse.body, List<Github.Issue>.class);
        }

        global List<Github.Issue> first() {
            super.paginate(this.lastResponse.first);
            return (List<Github.Issue>) JSON.deserialize(this.lastResponse.body, List<Github.Issue>.class);
        }

        global List<Github.Issue> all() {
            List<Github.Issue> issues = this.get('all', 'all', null, null, null, null, 100);
            while (this.hasNext) {
                issues.addAll(this.next());
            }
            return issues;
        }
    }

    /**
    * @description Client for Github Web Hooks. **Incomplete**.
    */
    global class HookClient extends BaseClient {

        global HookClient(Github parent) {
            this.parent = parent;
            this.endpoint = 'hooks';
        }

        /**
         *   @param state: Either open, closed, or all
         *   @param sort: Either due_date or completeness
         *   @param direction: Either asc or desc
        **/
        global List<Github.Hook> get() {
            this.makeRequest('', 'GET', null);
            return (List<Github.Hook>) JSON.deserialize(this.lastResponse.body, List<Github.Hook>.class);
        }

        global Github.Hook get(Integer num) {
            System.assert(num != null, 'Hook id is required to get a Hook.');
            this.makeRequest(num);
            return (Github.Hook) JSON.deserialize(this.lastResponse.body, Github.Hook.class);
        }

        global Github.Hook create(Github.Hook hook) {
            this.makeRequest(String.valueOf(hook.id), 'POST', JSON.serialize(hook));
            return (Github.Hook) JSON.deserialize(this.lastResponse.body, Github.Hook.class);
        }

        global Github.Hook put(Github.Hook hook) {
            this.makeRequest(String.valueOf(hook.id), 'PATCH', JSON.serialize(hook));
            return (Github.Hook) JSON.deserialize(this.lastResponse.body, Github.Hook.class);
        }

        global void remove(Github.Hook hook) {
            this.makeRequest(String.valueOf(hook.id), 'DELETE', null);
        }

        global List<Github.Hook> next() {
            this.paginate(this.lastResponse.next);
            return (List<Github.Hook>) JSON.deserialize(this.lastResponse.body, List<Github.Hook>.class);
        }

        global List<Github.Hook> prev() {
            this.paginate(this.lastResponse.prev);
            return (List<Github.Hook>) JSON.deserialize(this.lastResponse.body, List<Github.Hook>.class);
        }

        global List<Github.Hook> last() {
            this.paginate(this.lastResponse.last);
            return (List<Github.Hook>) JSON.deserialize(this.lastResponse.body, List<Github.Hook>.class);
        }

        global List<Github.Hook> first() {
            this.paginate(this.lastResponse.first);
            return (List<Github.Hook>) JSON.deserialize(this.lastResponse.body, List<Github.Hook>.class);
        }

        global List<Github.Hook> all() {
            List<Github.Hook> hooks = this.get();
            while (this.hasNext) {
                hooks.addAll(this.next());
            }
            return hooks;
        }

    }

    global BaseResponse makeRequest(String endpoint, String method, String body) {

        System.assert(rateLimitRemaining > 0, 'Maximum github requests reached.');

        String url = 'https://api.github.com/repos/' + organization + '/' + repository + '/';

        if (endpoint.contains('https://')) {
            url = endpoint;
        } else {
            url += endpoint;
        }

        HttpRequest req = new HttpRequest();

        if (method == 'PATCH') {
            String patchParam = '?';
            if (url.contains('?')) {
                patchParam = '&';
            }
            patchParam += '_HttpMethod=PATCH';
            req.setEndpoint(url+patchParam);
            req.setMethod('POST');
        } else {
            req.setEndpoint(url);
            req.setMethod(method);
        }

        if (body != null) {
            req.setBody(body);
        }

        Blob headerValue = Blob.valueOf(token+':x-oauth-basic');
        String authorizationHeader = 'BASIC ' + EncodingUtil.base64Encode(headerValue);
        req.setHeader('Authorization', authorizationHeader);
        req.setHeader('Accept', 'application/vnd.github.v3.full+json');
        req.setHeader('Content-Type', 'application/json');
        Http http = new Http();

        BaseResponse res = new BaseResponse(http.send(req));

        res.url = url;
        lastStatus = res.status;
        lastStatusCode = res.statusCode;
        rateLimit = res.statusCode;
        rateLimitRemaining = res.statusCode;

        System.assert(lastStatusCode > 199 && lastStatusCode < 300, res.body);

        return res;
    }

    global BaseResponse makeRequest(String endpoint) {
        return makeRequest(endpoint, 'GET', null);
    }

    global static String renameReserved(String body) {
        return body.replace('"number":', '"num":');
    }

    global static String renameReservedBack(String body) {
        return body.replace('"num":', '"number":')
                   .replace('"milestone":', '"milestoneObject":')
                   .replace('"milestoneNumber":', '"milestone":')
                   .replace('"assignee":', '"assigneeObject":')
                   .replace('"assigneeUsername":', '"assignee":');
    }

    global static String buildQueryString(Map<String, String> options) {
        List<String> finalOptions = new List<String>();

        for (String key : options.keySet()) {
            if (options.get(key) != null) {
                finalOptions.add(key + '=' + options.get(key));
            }
        }

        if (!finalOptions.isEmpty()) {
            String result = '?';
            for (String pair : finalOptions) {
                result += pair + '&';
            }
            return result;
        }
        return '';
    }

    global static String parseLinkUrl(String link) {
        String url = link.split('>;')[0];
        return url.replace('<', '');
    }

    global static Integer numFromUrl(String url) {
        List<String> parts = url.replace('https://github.com/', '').split('/');
        if (parts.size() == 4) {
            return Integer.valueOf(parts[3]);
        }
        return null;
    }

    global static Datetime offsetDate(Datetime dt) {
        if (dt != null) {
            return dt.addHours(20);
        }
        return null;
    }
}