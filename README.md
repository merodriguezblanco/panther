# Panther
A Ruby script that migrates issues, comments, milestones and labels from **GitHub Enterprise** to **GitHub**.

One of my current tasks at work was to migrate some git repositories from GitHub Enterprise to GitHub. Since we don't count with access to the [ghe-migrator](https://blog.github.com/2016-05-16-migrate-your-repositories-using-ghe-migrator/) tool in GitHub, we had to come up with an automated script solution to do the repositories migration.

Hope somebody finds this script useful as well!

## Usage
You will need to create a token in both GitHub accounts to run `panther`. You can do this in your GitHub profile settings page. For more information on this, please see [here](https://help.github.com/articles/creating-a-personal-access-token-for-the-command-line/).

Before running panther, you will need to:

```bash
$ bundle install
```

You can get some hints about how to run `panther` by running:

```bash
$ bundle exec ruby panther.rb -h
Usage: panther.rb [arguments]
        --labels                     Migrates labels
        --milestones                 Migrates milestones
        --issues                     Migrates issues
        --comments                   Migrates comments
        --source-token=TOKEN         Personal token for the GitHub where you are migrating from
        --source-domain=DOMAIN       Domain for GitHub where you are migrating from
        --source-organization=ORG    Organization in GitHub source where repository lives
        --destination-token=TOKEN    Personal token for GitHub destination
        --destination-organization=ORG
                                     Organization in GitHub destination where repository will be migrated
        --repository=REPOSITORY      Name of the repository to be migrated
```

For instance, if you wanted to migrate a repository called `fried_chicken` from GitHub Enterprise to GitHub, you would run:

```bash
$ bundle exec ruby panther.rb --source-token=<SOURCE-TOKEN>
                              --source-domain=enterprise.github.com
                              --source-organization=Chicken
                              --destination-token=<DEST-TOKEN>
                              --destination-organization=Bird
                              --repository=fried_chicken
                              --labels --issues --comments --milestones
```

The above command will migrate all issues, comments, labels and milestones from `https://enterprise.github.com/Chicken/fried_chicken` to `https://github.com/Bird/fried_chicken`.

Keep in mind that the source repository name is expected to be the same in both GitHubs (this could be improved).

Since `panther` is using your personal GitHub tokens for fetching and posting stuff, all issues and comments will have your username for the author. In order to know who the real author of the issues and comments were, `panther` adds a prefix template to each issue and comment that mentions the author's username and date in which those were posted.

## Dependencies
* Panther script makes use of [octokit](https://github.com/octokit/octokit.rb) to hit GitHub's Enterprise and GitHub's APIs.

## Contributing
We welcome and appreciate [contributions](CONTRIBUTING.md)!
