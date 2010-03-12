package Dist::Zilla::PluginBundle::AVAR;
# ABSTRACT: BeLike::AVAR when you build your dists

use 5.10.0;
use Moose;
use Moose::Autobox;
with 'Dist::Zilla::Role::PluginBundle';

=head1 DESCRIPTION

This is the plugin bundle that AVAR uses.

=cut

use Dist::Zilla::PluginBundle::Filter;
use Dist::Zilla::PluginBundle::Git;

sub bundle_config {
    my ($self, $section) = @_;

    my $args        = $section->{payload};
    my $dist        = $args->{dist};
    my $ldist       = lc $dist;
    my $github_user = $args->{github_user} // 'avar';

    my @plugins = Dist::Zilla::PluginBundle::Filter->bundle_config({
        name    => $section->{name} . '/@Classic',
        payload => {
            bundle => '@Classic',
            remove => [
                # Don't add a =head1 VERSION
                'PodVersion',
                # This will inevitably whine about completely reasonable stuff
                'PodTests',
            ],
        },
    });

    my $prefix = 'Dist::Zilla::Plugin::';
    my @extra = map {[ "$section->{name}/$_->[0]" => "$prefix$_->[0]" => $_->[1] ]}
    (
        [ AutoPrereq  => {} ],
        [ MetaJSON     => { } ],
        [
            MetaNoIndex => {
                # Ignore these if they're there
                directory => [ map { -d $_ ? $_ : () } qw( inc t xt utils ) ],
            }
        ],
        # Produce README from lib/
        [ ReadmeFromPod => {} ],
        [
            MetaResources => {
                homepage => "http://search.cpan.org/dist/$dist/",
                bugtracker => "http://github.com/$github_user/$ldist/issues",
                repository => "http://github.com/$github_user/$ldist",
                license => 'http://dev.perl.org/licenses/',
                Ratings => "http://cpanratings.perl.org/d/$dist",
            }

        ],
        # Bump the Changlog
        [
            NextRelease => {
                format => '%-2v %{yyyy-MM-dd HH:mm:ss}d',
            }
        ],
        [ 'Git::Check' => {} ],
        [
            'Git::Tag' => {
                tag_format => '%v',
            }
        ]
    );

    push @plugins, @extra;

    return @plugins;
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;
