# ABSTRACT: Embed a self-extracting tarball in a Perl module.
package App::FilePacker;
use Moo;
use Archive::Tar;
use File::Find;
use Cwd;

our $VERSION = '0.001';

# Name of the module to create,
# used in the package declaration.
# ex: Foo::Bar
has name => (
    is => 'ro',
);

# Name of the file to output to.
# ex: Bar.pm
has out => (
    is => 'ro',
);

# Directory to package
has dir => (
    is  => 'ro',
    isa => sub {
        die "$_[0] is not a directory" unless -d $_[0];
    },
);

has tarball => (
    is       => 'lazy',
    init_arg => undef,
);

sub _build_tarball {
    my ( $self ) = @_;

    my $tarball = Archive::Tar->new;


    my $orig = getcwd;
    chdir $self->dir
        or die "Failed to chdir to " . $self->dir . ": $!";

    find({
        wanted => sub {
            return if $_ =~ m|/\.\.?$|; # Skip . and ..
            $tarball->add_files( $_ );
        },
        no_chdir => 1,
    }, '.' );

    chdir $orig
        or die "Failed to chdir to $orig after tarball creation: $!";

    return $tarball;
}

# Body of module to extract embedded tar file.
has module_body => (
    is => 'ro',
    default => sub { return join "\n",
        'use warnings;',
        'use strict;',
        'use Archive::Tar;',
        'use File::Path qw( make_path );',
        '',
        'sub extract {',
        '    my ( $path ) = @_;',
        '',
        '    make_path( $path );',
        '',
        '    chdir $path',
        '        or die "Failed to move into path $path to extract files.\n";',
        '',
        '    Archive::Tar->new( \*DATA, 0, { extract => 1 } );',
        '}';
    },
);

sub write {
    my ( $self ) = @_;

    open my $sf, ">", $self->out
        or die "Failed to open " . $self->out . " for writing: $!";

    print $sf "package " . $self->name . ";\n";
    print $sf $self->module_body;
    print $sf "1;\n";
    print $sf "__DATA__\n";
    $self->tarball->write( $sf );
    close $sf;

}

1;
