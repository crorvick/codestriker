###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Action object for handling the submission of a new topic.

package Codestriker::Action::SubmitTopic;

use strict;

use Codestriker::Model::Topic;
use Codestriker::Smtp::SendEmail;
use Codestriker::Http::Render;

# If the input is valid, create the appropriate topic into the database.
sub process($$$) {
    my ($type, $http_input, $http_response) = @_;

    my $query = $http_response->get_query();

    # Check that the appropriate fields have been filled in.
    my $topic_title = $http_input->get('topic_title');
    my $topic_description = $http_input->get('topic_description');
    my $topic_text = $http_input->get('topic_text');
    my $reviewers = $http_input->get('reviewers');
    my $email = $http_input->get('email');
    my $cc = $http_input->get('cc');
    my $fh = $http_input->get('fh');
    my $bug_ids = $http_input->get('bug_ids');

    if ($topic_title eq "") {
	$http_response->error("No topic title was entered");
    }
    if ($topic_description eq "") {
	$http_response->error("No topic description was entered");
    }
    if ($email eq "") {
	$http_response->error("No email address was entered");
    }	
    if ($topic_text eq "" && !defined $fh) {
	$http_response->error("No topic text or filename was entered");
    }
    if (defined $fh && $topic_text ne "") {
	$http_response->error("Both topic text and uploaded file was entered");
    }
    if ($reviewers eq "") {
	$http_response->error("No reviewers were entered");
    }

    $http_response->generate_header("", "Create new topic", $email, $reviewers,
				    $cc, "", "");

    # If the topic text has been uploaded from a file, read from it now.
    if (defined $fh) {
	while (<$fh>) {
	    $topic_text .= $_;
	}
    }

    # Remove \r from the topic text.
    $topic_text =~ s/\r//g;

    # For "hysterical" reasons, the topic id is randomly generated.  Seed the
    # generator based on the time and the pid.  Keep searching until we find
    # a free topicid.  In 99% of the time, we will get a new one first time.
    srand(time() ^ ($$ + ($$ << 15)));
    my $topicid;
    do {
	$topicid = int rand(10000000);
    } while (Codestriker::Model::Topic->exists($topicid));
    
    # Create the topic in the model.
    if (!Codestriker::Model::Topic->create($topicid, $email, $topic_title,
					   $bug_ids, $reviewers, $cc,
					   $topic_description, $topic_text)) {
	$http_response->error("Oh oh - database problem, please check logs.");
    }
    
    # Obtain a URL builder object and determine the URL to the topic.
    my $url_builder = Codestriker::Http::UrlBuilder->new($query);
    my $default_mode = $Codestriker::default_topic_create_mode;
    my $topic_url =
	     $url_builder->view_url_extended($topicid, -1, $default_mode,
					     "", $email, $query->url());

    # Send an email to the document author and all contributors with the
    # relevant information.  The person who wrote the comment is indicated
    # in the "From" field, and is BCCed the email so they retain a copy.
    my $from = $email;
    my $to = $reviewers;
    my $bcc = $email;
    my $subject = "[REVIEW] Topic \"topic_title\" created\n";
    my $body =
	"Topic \"$topic_title\" created\n" .
	"Author: $email\n" .
	(($bug_ids ne "") ? "Bug IDs: $bug_ids\n" : "") .
	"Reviewers: $reviewers\n" .
	"URL: $topic_url\n\n" .
	"Description:\n" .
	"$Codestriker::Smtp::SendEmail::EMAIL_HR\n\n" .
	"$topic_description\n";

    # Send the email notification out.
    if (!Codestriker::Smtp::SendEmail->doit($from, $to, $cc, $bcc, $subject,
					    $body)) {
	$http_response->error("Failed to send topic creation email");
    }

    # Indicate to the user that the topic has been created and an email has
    # been sent.
    print $query->h1("Topic created");
    print "Topic title: \"$topic_title\"", $query->br;
    print "Author: $email", $query->br;
    print "Topic URL: ", $query->a({href=>"$topic_url"}, $topic_url);
    print $query->p, "Email has been sent to: $email, $reviewers";
    print ", $cc" if (defined $cc && $cc ne "");
}

1;