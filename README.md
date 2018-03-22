# PagerDuty Schedule Cop

It is very easy for PagerDuty duties schedules to shift by one and causing disruption to it all when a user is off-boarded from an organization. PagerDuty doesn't have any offer any callbacks or insights into when this occurs or where the off-boarded user was previously.

## Setup

- Generate a https://github.com/settings/tokens with `public_repo` & `user` scopes.
- Generate a PagerDuty API key if you don't already have one https://account.pagerduty.com/api_keys. You can generate a read only key if you like.

## Configuration

PagerDuty Schedule Cop uses a whitelist of schedules you'd like to have monitored:

```yaml
github-dotcom-oncall:
  pagerduty_schedule_id: PH9X1BE
  github_repository: dewski/testing
```

The `pagerduty_schedule_id` can be found in the URL when visiting a schedule on PagerDuty. For example:

> https://makeshift.pagerduty.com/schedules#PH9X1BE

The `github_repository` is the repository where you'd like PagerDuty Schedule Cop to open an issue to notify you of someone being off-boarded.

## Deployment

PagerDuty Schedule Cop can run on Heroku as a standalone application using a [free Redis instance](https://elements.heroku.com/addons/redistogo) & the [Heroku Scheduler](https://elements.heroku.com/addons/scheduler).

```sh
$ heroku addons:create scheduler:standard
$ heroku addons:create redistogo:nano
```

You'll want the scheduler to run `bin/check-schedules` every hour to 24 hours depending how soon you'd like to be notified after a user is off-boarded.

The environment variables you'll need to set:

```sh
heroku config:set PAGERDUTY_API_KEY=key OCTOKIT_ACCESS_TOKEN=token
```

The `REDIS_URL` will be provided automatically after you add a Redis addon to the instance.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
