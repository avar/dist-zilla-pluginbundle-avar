package Dist::Zilla::PluginBundle::AVAR;

use 5.10.0;
use Moose;
use Moose::Autobox;

with 'Dist::Zilla::Role::PluginBundle';

use Dist::Zilla::PluginBundle::Filter;
use Dist::Zilla::PluginBundle::Git;
use Dist::Zilla::Plugin::BumpVersionFromGit;
use Dist::Zilla::Plugin::MetaNoIndex;
use Dist::Zilla::Plugin::ReadmeFromPod;
use Dist::Zilla::Plugin::MakeMaker::Awesome;
use Dist::Zilla::Plugin::CompileTests;
use Dist::Zilla::Plugin::Authority;

sub bundle_config {
    my ($self, $section) = @_;

    my $args        = $section->{payload};
    my $dist        = $args->{dist} // die "You must supply a dist =, it's equivalent to what you supply as name =";
    my $ldist       = lc $dist;
    my $github_user = $args->{github_user} // 'avar';
    my $authority   = $args->{authority} // 'cpan:AVAR';
    my $no_a_pre    = $args->{no_AutoPrereq} // 0;
    my $use_mm      = $args->{use_MakeMaker} // 1;
    my $use_ct      = $args->{use_CompileTests} // 1;
    my $bugtracker  = $args->{bugtracker}  // 'rt';
    warn "AVAR: Don't use GitHub as a tracker" if $bugtracker eq 'github';
    my $homepage    = $args->{homepage};
    warn "AVAR: Upgrade to new format" if $args->{repository};
    my $repository_url  = $args->{repository_url};
    my $repository_web  = $args->{repository_web};
    my $nextrelease_format = $args->{nextrelease_format} // '%-2v %{yyyy-MM-dd HH:mm:ss}d',
    my $tag_message = $args->{git_tag_message};
    my ($tracker, $tracker_mailto);
    my $page;
    my ($repo_url, $repo_web);

    given ($bugtracker) {
        when ('github') { $tracker = "http://github.com/$github_user/$ldist/issues" }
        when ('rt')     {
            $tracker = "https://rt.cpan.org/Public/Dist/Display.html?Name=$dist";
            $tracker_mailto = sprintf 'bug-%s@rt.cpan.org', $dist;
        }
        default         { $tracker = $bugtracker }
    }

    given ($repository_url) {
        when (not defined) {
            $repo_web = "http://github.com/$github_user/$ldist";
            $repo_url = "git://github.com/$github_user/$ldist.git";
        }
        default {
            $repo_web = $repository_web;
            $repo_url = $repository_url;
        }
    }

    given ($homepage) {
        when (not defined) { $page = "http://search.cpan.org/dist/$dist/" }
        default            { $page = $homepage }
    }

    my @plugins = Dist::Zilla::PluginBundle::Filter->bundle_config({
        name    => $section->{name} . '/@Classic',
        payload => {
            bundle => '@Classic',
            remove => [
                # Don't add a =head1 VERSION
                'PodVersion',
                # This will inevitably whine about completely reasonable stuff
                'PodCoverageTests',
                # Use my MakeMaker
                'MakeMaker',
            ],
        },
    });

    my $prefix = 'Dist::Zilla::Plugin::';
    my @extra = map {[ "$section->{name}/$_->[0]" => "$prefix$_->[0]" => $_->[1] ]}
    (
        [
            BumpVersionFromGit => {
                version_regexp => '^(\d.*)$',
            }
        ],
        ($no_a_pre
         ? ()
         : ([ AutoPrereqs  => { } ])),
        [ MetaJSON     => { } ],
        [
            MetaNoIndex => {
                # Ignore these if they're there
                directory => [ map { -d $_ ? $_ : () } qw( inc t xt utils example examples ) ],
            }
        ],
        # Produce README from lib/
        [ ReadmeFromPod => {} ],
        [
            MetaResources => {
                homepage => $page,
                'bugtracker.web' => $tracker,
                'bugtracker.mailto' => $tracker_mailto,
                'repository.type' => 'git',
                'repository.url' => $repo_url,
                'repository.web' => $repo_web,
                license => 'http://dev.perl.org/licenses/',
            }

        ],
        [
            Authority => {
                authority   => $authority,
                do_metadata => 1,
            }
        ],
        # Bump the Changlog
        [
            NextRelease => {
                format => $nextrelease_format,
            }
        ],

        # Maybe use MakeMaker, maybe not
        ($use_mm
         ? ([ MakeMaker  => { } ])
         : ()),

        # Maybe CompileTests
        ($use_ct
         ? ([ CompileTests  => { } ])
         : ()),
    );
    push @plugins, @extra;

    push @plugins, Dist::Zilla::PluginBundle::Git->bundle_config({
        name    => "$section->{name}/\@Git",
        payload => {
            tag_format => '%v',
            ($tag_message
             ? (tag_message => $tag_message)
             : ()),
        },
    });

    return @plugins;
}

__PACKAGE__->meta->make_immutable;

=head1 NAME

Dist::Zilla::PluginBundle::AVAR - Use L<Dist::Zilla> like AVAR does

=head1 DESCRIPTION

This is the plugin bundle that AVAR uses. Use it as:

    [@AVAR]
    ;; same as `name' earlier in the dist.ini, repeated due to
    ;; limitations of the Dist::Zilla plugin interface
    dist = MyDist
    ;; If you're not avar
    github_user = imposter
    ;; Bugtracker github or rt
    bugtracker = rt
    ;; custom homepage/repository
    homepage = http://example.com
    repository = http://git.example.com/repo.git
    ;; use various stuff or not
    no_AutoPrereq = 1 ; evil for this module
    use_MakeMaker = 0 ; If using e.g. MakeMaker::Awesome instead
    use_CompileTests = 0 ; I have my own compile tests here..
    ;; cpan:AVAR is the default AUTHORITY
    authority = cpan:AVAR

It's equivalent to:

    [@Filter]
    bundle = @Classic
    remove = PodVersion
    remove = PodCoverageTests
    
    [VersionFromPrev]
    [AutoPrereqs]
    [MetaJSON]

    [MetaNoIndex]
    ;; Only added if these directories exist
    directory = inc
    directory = t
    directory = xt
    directory = utils
    directory = example
    directory = examples
    
    [ReadmeFromPod]

    [MetaResources]
    ;; $github_user is 'avar' by default, $lc_dist is lc($dist)
    homepage   = http://search.cpan.org/dist/$dist/
    bugtracker.mailto = bug-$dist@rt.cpan.org
    bugtracker.web = https://rt.cpan.org/Public/Dist/Display.html?Name=$dist
    repository.web = http://github.com/$github_user/$lc_dist
    repository.url = git://github.com/$github_user/$lc_dist.git
    repository.type = git
    license    = http://dev.perl.org/licenses/

    [Authority]
    authority   = cpan:AVAR
    do_metadata = 1
    
    [NextRelease]
    format = %-2v %{yyyy-MM-dd HH:mm:ss}d
    
    [@Git]
    tag_format = %v

=head1 AUTHOR

E<AElig>var ArnfjE<ouml>rE<eth> Bjarmason <avar@cpan.org>

=head1 LICENSE AND COPYRIGHT

Copyright 2010 E<AElig>var ArnfjE<ouml>rE<eth> Bjarmason <avar@cpan.org>

This program is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.
    
=cut
