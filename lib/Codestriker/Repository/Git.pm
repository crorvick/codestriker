###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Git repository class

package Codestriker::Repository::Git;

use strict;
use FileHandle;
use Fatal qw / open close / ;

use Codestriker::Repository;
@Codestriker::Repository::Git::ISA = ("Codestriker::Repository");

sub new_local ($$$) {
    my ($type, $path) = @_;

    my $self = Codestriker::Repository->new(":git:${path}");

    $self->{gitdir} = -d "$path/.git" ? "$path/.git" : $path;

    bless $self, $type;
}

# We could also support gitweb? ssh access?

sub retrieve ($$$\$) {
    my ($self, $filename, $blob_hash, $filedata_ref) = @_;
    # Command: git show <commit>:<file>
    my $read_data = '';
    my $read_stdout_fh = new FileHandle;
    open($read_stdout_fh, '>', \$read_data);
    Codestriker::execute_command($read_stdout_fh, undef, $Codestriker::git,
                                 '--git-dir=' . $self->{gitdir}, 'show',
                                 $blob_hash);

    # Process the data for the topic.
    open($read_stdout_fh, '<', \$read_data);
    for (my $i = 1; <$read_stdout_fh>; $i++) {
        $_ = Codestriker::decode_topic_text($_);
        chop;
        $$filedata_ref[$i] = $_;
    }
    close $read_stdout_fh;
}

sub getDiff ($$$$$$) {
    my ($self, $start_commit, $end_commit, $path,
        $stdout_fh, $stderr_fh, $default_to_head) = @_;
    # Command: git diff -U6 <start> <end>

    # Default end_commit to HEAD
    if ($end_commit eq "") {
        $end_commit = "HEAD";
    }

    # Default start_commit to the merge-base of HEAD and end_commit
    if ($start_commit eq "") {
        my @args = ();
        push @args, "--git-dir=$self->{gitdir}";
        push @args, 'merge-base';
        push @args, 'HEAD';
        push @args, $end_commit;
        my $read_data = '';
        my $read_stdout_fh = new FileHandle;
        open($read_stdout_fh, '>', \$read_data);
        Codestriker::execute_command($read_stdout_fh, undef,
            $Codestriker::git, @args);
        $start_commit = $1 if ($read_data =~ /^([0-9a-f]{40})$/);
    }

    sub get_prefix {
        my ($ref) = @_;
        my @args = ();
        push @args, "--git-dir=$self->{gitdir}";
        push @args, 'rev-parse';
        push @args, '--verify';
        push @args, '--short';
        push @args, $ref;
        my $read_data = '';
        my $read_stdout_fh = new FileHandle;
        open($read_stdout_fh, '>', \$read_data);
        Codestriker::execute_command($read_stdout_fh, undef,
            $Codestriker::git, @args);
        return $read_data =~ /^([0-9a-f]{7})$/ ? $1 : $ref;
    };

    my $start_prefix = get_prefix($start_commit);
    my $end_prefix = get_prefix($end_commit);

    my @args = ();
    push @args, '--git-dir=' . "$self->{gitdir}";
    push @args, 'diff';
    # Get 6 lines of context
    push @args, '-U6';
    # Header will use full SHA1 in 'index <blob>..<blob>' line
    push @args, '--full-index';
    # Header will say diff --git $start_prefix/<file> $end_prefix/<file>
    push @args, "--src-prefix=$start_prefix/";
    push @args, "--dst-prefix=$end_prefix/";
    push @args, "$start_commit";
    push @args, "$end_commit";
    push @args, '--';
    if ($path ne ".") {
        push @args, "$path";
    }

    Codestriker::execute_command($stdout_fh, $stderr_fh, $Codestriker::git, @args);

    return $Codestriker::OK;
}

sub getRoot ($) {
    my ($self) = @_;
    return $self->{gitdir}
}

1;
