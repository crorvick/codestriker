###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Action object for handling the submission of changing a topic's state.

package Codestriker::Action::ChangeTopicState;

use strict;

# Attempt to change the topic's state.
sub process($$$) {
    my ($type, $http_input, $http_response) = @_;

    my $query = $http_response->get_query();

    # Check that the appropriate fields have been filled in.
    my $topic = $http_input->get('topic');
    my $mode = $http_input->get('mode');
    my $version = $http_input->get('version');
    my $topic_state = $http_input->get('topic_state');
    my $email = $http_input->get('email');

    # Retrieve the appropriate topic details (for the bug_ids).
    my ($_document_author, $_document_title, $_document_bug_ids,
	$_document_reviewers, $_document_cc, $_description,
	$_topic_data, $_document_creation_time, $_document_modified_time,
	$_topic_state, $_version);
    Codestriker::Model::Topic->read($topic, \$_document_author,
				    \$_document_title, \$_document_bug_ids,
				    \$_document_reviewers, \$_document_cc,
				    \$_description, \$_topic_data,
				    \$_document_creation_time,
				    \$_document_modified_time, \$_topic_state,
				    \$_version);
    # Update the topic's state.
    my $timestamp = Codestriker->get_timestamp(time);
    Codestriker::Model::Topic->change_state($topic, $topic_state, $timestamp,
					    $version);

    # If Codestriker is linked to a bug database, and this topic is associated
    # with some bugs, update them with an appropriate message.
    if ($_document_bug_ids ne "" && $Codestriker::bug_db ne "") {
	my $bug_db_connection =
	    Codestriker::BugDB::BugDBConnectionFactory->getBugDBConnection();
	$bug_db_connection->get_connection();
	my @ids = split /, /, $_document_bug_ids;
	my $url_builder = Codestriker::Http::UrlBuilder->new($query);
	my $topic_url = $url_builder->view_url_extended($topic, -1, "", "",
							"", $query->url());
	my $text = "Codestriker topic: $topic_url\n" .
	    "State changed to \"$topic_state\" by $email.\n";
	for (my $i = 0; $i <= $#ids; $i++) {
	    $bug_db_connection->update_bug($ids[$i], $text);
	}
	$bug_db_connection->release_connection();
    }

    # Redirect the user to the view topic page.
    my $url_builder = Codestriker::Http::UrlBuilder->new($query);
    my $redirect_url = $url_builder->view_url($topic, -1, $mode);
    print $query->redirect(-URI=>$redirect_url);
}

1;
