###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Method for submitting a new comment.

package Codestriker::Http::Method::AddCommentMethod;

use strict;
use Codestriker::Http::Method;

@Codestriker::Http::Method::AddCommentMethod::ISA = ("Codestriker::Http::Method");

# Generate a URL for this method.
sub url() {
    my ($self, %args) = @_;
	
    if ($self->{cgi_style}) {
        return $self->{url_prefix} . "?action=submit_comment";
    } else {
	    die "Parameter topicid missing" unless defined $args{topicid};
   		die "Parameter projectid missing" unless defined $args{projectid};

    	return $self->{url_prefix} . "/project/$args{projectid}/topic/$args{topicid}/comment" .
    	       (defined $args{filenumber} && $args{filenumber} ne "" ? "/$args{filenumber}|$args{line}|$args{new}/add" : "");
    }
}

sub extract_parameters {
	my ($self, $http_input) = @_;
	
	my $action = $http_input->{query}->param('action'); 
    my $path_info = $http_input->{query}->path_info();
    if ($self->{cgi_style} && defined $action && $action eq "submit_comment") {  
		$http_input->extract_cgi_parameters();
		return 1;
	} elsif ($path_info =~ m{^/project/\d+/topic/\d+/comment/(\d+)\|(\d+)\|(\d+)/add}) {
	    $self->_extract_nice_parameters($http_input,
	                                    project => 'projectid', topic => 'topic',
	                                    anchor => 'anchor', context => 'context');
		$http_input->{fn} = $1;
		$http_input->{line} = $2;
		$http_input->{new} = $3;
		return 1;
	} else {
		return 0;
	}
}

sub execute {
	my ($self, $http_input, $http_output) = @_;
	
	Codestriker::Action::SubmitNewComment->process($http_input, $http_output);
}

1;