###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Model object for handling topic data.

package Codestriker::Model::Topic;

use strict;

use Codestriker::DB::DBI;
use Codestriker::Model::File;
use Codestriker::Model::Metrics;

sub new {
    my ($class, $topicid) = @_;
    my $self = {};
        
    $self->{topicid} = 0;
    $self->{author} = "";
    $self->{title} = "";
    $self->{bug_ids} = "";
    $self->{reviewers} = "";
    $self->{cc} = "";
    $self->{description} = "";
    $self->{document} = "";
    $self->{creation_ts} = "";
    $self->{modified_ts} = "";
    $self->{topic_state} = "";
    $self->{topic_state_id} = 0;
    $self->{version} = 0;
    $self->{repository} = "";
    $self->{project_id} = "";
    $self->{project_name} = "";
    $self->{comments} = [];
    $self->{metrics} = Codestriker::Model::Metrics->new($topicid);

    bless $self, $class;

    if (defined($topicid)) {
	$self->read($topicid);
    }
   
    return $self;
}

# Delete the specified participant type from the topic.
sub _delete_participants($$$) {
    my ($self, $dbh, $type) = @_;

    my $delete_participants =
	$dbh->prepare_cached('DELETE FROM participant ' .
			     'WHERE topicid = ? AND type = ?');
    my $success = defined $delete_participants;

    $success &&= $delete_participants->execute($self->{topicid}, $type);
    return $success;
}

# Insert the specified participants into the topic.
sub _insert_participants($$$$$) {
    my ($self, $dbh, $type, $participants, $timestamp) = @_;

    my $insert_participant =
	$dbh->prepare_cached('INSERT INTO participant (email, topicid, type,' .
			     'state, modified_ts, version) ' .
			     'VALUES (?, ?, ?, ?, ?, ?)');
    my $success = defined $insert_participant;

    my @participants = split /, /, $participants;
    for (my $i = 0; $i <= $#participants; $i++) {
	$success &&= $insert_participant->execute($participants[$i],
						  $self->{topicid}, $type, 0,
						  $timestamp, 0);
    }
    
    return $success;
}

# Delete the bugids associated with a particular topic.
sub _delete_bug_ids($$) {
    my ($self, $dbh) = @_;

    my $delete_topicbug =
	$dbh->prepare_cached('DELETE FROM topicbug WHERE topicid = ?');
    my $success = defined $delete_topicbug;

    $success &&= $delete_topicbug->execute($self->{topicid});
    return $success;
}

# Insert the comma-separated list of bug_ids into the topic.
sub _insert_bug_ids($$$) {
    my ($self, $dbh, $bug_ids) = @_;

    my $insert_bugs =
	$dbh->prepare_cached('INSERT INTO topicbug (topicid, bugid) ' .
			     'VALUES (?, ?)');
    my $success = defined $insert_bugs;

    my @bug_ids = split /, /, $bug_ids;
    for (my $i = 0; $i <= $#bug_ids; $i++) {
	$success &&= $insert_bugs->execute($self->{topicid}, $bug_ids[$i]);
    }

    return $success;
}

# Create a new topic with all of the specified properties.
sub create($$$$$$$$$$$$) {
    my ($self, $topicid, $author, $title, $bug_ids, $reviewers, $cc,
	$description, $document, $repository, $projectid,
	$deltas_ref) = @_;

    my $timestamp = Codestriker->get_timestamp(time);        
        
    $self->{topicid} = $topicid;
    $self->{author} = $author;
    $self->{title} = $title;
    $self->{bug_ids} = $bug_ids;
    $self->{reviewers} = $reviewers;
    $self->{cc} = $cc;
    $self->{description} = $description;
    $self->{document} = $document;
    $self->{creation_ts} = $timestamp;
    $self->{modified_ts} = $timestamp;
    $self->{topic_state} = 0;
    $self->{topic_state_id} = 0;
    $self->{project_id} = $projectid;
    $self->{version} = 0;
    $self->{repository} = $repository;
    $self->{metrics} = Codestriker::Model::Metrics->new($topicid);
                            
    # Obtain a database connection.
    my $dbh = Codestriker::DB::DBI->get_connection();

    # Create the prepared statements.
    my $insert_topic =
	$dbh->prepare_cached('INSERT INTO topic (id, author, title, ' .
			     'description, document, state, creation_ts, ' .
			     'modified_ts, version, repository, projectid) ' .
			     'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)');
    my $success = defined $insert_topic;

    # Create all of the necessary rows.  It is assumed state 0 is the initial
    # state.
    $success &&= $insert_topic->execute($topicid, $author, $title,
					$description, $document, 0,
					$timestamp, $timestamp, 0,
					$repository, $projectid);
	
    # Insert the associated bug records.
    $success &&= $self->_insert_bug_ids($dbh, $bug_ids);

    # Insert the reviewers and cc participants.
    $success &&=
	$self->_insert_participants($dbh,
				    $Codestriker::PARTICIPANT_REVIEWER,
				    $reviewers, $timestamp);
    $success &&=
	$self->_insert_participants($dbh,
				    $Codestriker::PARTICIPANT_CC,
				    $cc, $timestamp);

    # Create the appropriate delta rows.
    $success &&= Codestriker::Model::File->create($dbh, $topicid, $deltas_ref);
    
    Codestriker::DB::DBI->release_connection($dbh, $success);

    die $dbh->errstr unless $success;
}

# Read the contents of a specific topic, and return the results in the
# provided reference variables.
sub read($$) {
    my ($self, $topicid) = @_;
    
    $self->{topicid} = $topicid;    

    # Obtain a database connection.
    my $dbh = Codestriker::DB::DBI->get_connection();

    # Setup the prepared statements.
    my $select_topic = $dbh->prepare_cached('SELECT topic.id, topic.author, ' .
					    'topic.title, ' .
					    'topic.description, ' .
					    'topic.document, topic.state, ' .
					    'topic.creation_ts, ' .
					    'topic.modified_ts, ' .
					    'topic.version, ' .
					    'topic.repository, ' .
					    'project.id, project.name ' .
					    'FROM topic, project ' .
					    'WHERE topic.id = ? AND ' .
					    'topic.projectid = project.id');
    my $select_bugs =
	$dbh->prepare_cached('SELECT bugid FROM topicbug WHERE topicid = ?');
    my $select_participants =
	$dbh->prepare_cached('SELECT type, email FROM participant ' .
			     'WHERE topicid = ?');

    my $success = defined $select_topic && defined $select_bugs &&
	defined $select_participants;
    my $rc = $Codestriker::OK;

    # Retrieve the topic information.
    $success &&= $select_topic->execute($topicid);

    my ($id, $author, $title, $description, $document, $state,
	$creationtime, $modifiedtime, $version, $repository,
	$projectid, $projectname);

    if ($success) {
	($id, $author, $title, $description, $document, $state,
	 $creationtime, $modifiedtime, $version, $repository,
	 $projectid, $projectname)
	    = $select_topic->fetchrow_array();
	$select_topic->finish();

	if (!defined $id) {
	    $success = 0;
	    $rc = $Codestriker::INVALID_TOPIC;
	}
    }

    # Retrieve the bug relating to this topic.
    my @bugs = ();
    $success &&= $select_bugs->execute($topicid);
    if ($success) {
	my @data;
	while (@data = $select_bugs->fetchrow_array()) {
	    push @bugs, $data[0];
	}
	$select_bugs->finish();
    }

    # Retrieve the participants in this review.
    my @reviewers = ();
    my @cc = ();
    $success &&= $select_participants->execute($topicid);
    if ($success) {
	while (my @data = $select_participants->fetchrow_array()) {
	    if ($data[0] == 0) {
		push @reviewers, $data[1];
	    } else {
		push @cc, $data[1];
	    }
	}
	$select_participants->finish();
    }

    # Close the connection, and check for any database errors.
    Codestriker::DB::DBI->release_connection($dbh, $success);

    # Store the data into the referenced variables if the operation was
    # successful.
    if ($success) {
	$self->{author} = $author;
	$self->{title} = $title;
	$self->{bug_ids} = join ', ', @bugs;
	$self->{reviewers} = join ', ', @reviewers;
	$self->{cc} = join ', ', @cc;
	$self->{description} = $description;
	$self->{document} = $document;
	$self->{creation_ts} = $creationtime;
	$self->{modified_ts} = $modifiedtime;
	$self->{topic_state} = $Codestriker::topic_states[$state];
	$self->{topic_state_id} = $state;
	$self->{project_id} = $projectid;
	$self->{project_name} = $projectname;
	$self->{version} = $version;
        $self->{metrics} = Codestriker::Model::Metrics->new($topicid);
	
	# Set the repository to the default system value if it is not defined.
	if (!defined $repository || $repository eq "") {
	    $self->{repository} = $Codestriker::default_repository;
	} else {
	    $self->{repository} = $repository;
	}
    }

    return $success ? $Codestriker::OK : $rc;
}

# Reads from the db if needed, and returns the list of comments for
# this topic. If the list of comments have already been returned, the
# function will skip the db call, and just return the list from
# memory.
sub read_comments {
    my ($self) = shift;

    if (scalar(@{$self->{comments}}) == 0) {
	my @comments = Codestriker::Model::Comment->read_all_comments_for_topic($self->{topicid});
    
	$self->{comments} = \@comments;
    }

    return @{$self->{comments}};
}

# Determine if the specified topic id exists in the table or not.
sub exists($) {
    my ($topicid) = @_;

    # Obtain a database connection.
    my $dbh = Codestriker::DB::DBI->get_connection();

    # Prepare the statement and execute it.
    my $select_topic = $dbh->prepare_cached('SELECT COUNT(*) FROM topic ' .
					    'WHERE id = ?');
    my $success = defined $select_topic;
    $success &&= $select_topic->execute($topicid);

    my $count;
    if ($success) {
	($count) = $select_topic->fetchrow_array();
	$select_topic->finish();
    }

    Codestriker::DB::DBI->release_connection($dbh, $success);
    die $dbh->errstr unless $success;

    return $count;
}

# This function returns the metrics objects that are part of the topic.
sub get_metrics {
    my ($self) = @_;

    return $self->{metrics};
}


# This function is used to create a new topic id. The function insures 
# that the new topic id is difficult to guess, and is not taken in the 
# database already.
sub create_new_topicid {
    # For "hysterical" reasons, the topic id is randomly generated.  Seed the
    # generator based on the time and the pid.  Keep searching until we find
    # a free topicid.  In 99% of the time, we will get a new one first time.
    srand(time() ^ ($$ + ($$ << 15)));
    my $topicid;
    do {
	$topicid = int rand(10000000);
    } while (Codestriker::Model::Topic::exists($topicid));
    
    return $topicid;
}

# Everytime a topic is stored the version number is incremented. When
# a page is created it includes the version number of the topic used
# to create the page. The user posts information back to server to
# change, the version information needs to be checked to make sure
# somebody else has not modified the server.
sub check_for_stale($$) {
    my ($self, $version) = @_;

    return $self->{version} ne $version;
}


# Update the properties of the specified topic. This is not implemented
# very efficiently, however it is not expected to be called very often.
sub update($$$$$$$$$$) {
    my ($self, $new_title, $new_author, $new_reviewers, $new_cc,
	$new_repository, $new_bug_ids, $new_projectid, $new_description,
	$new_state) = @_;

    # First check that the version matches the current topic version in the
    # database.
    my $dbh = Codestriker::DB::DBI->get_connection();
    my $select_topic =
	$dbh->prepare_cached('SELECT version, creation_ts ' .
			     'FROM topic WHERE id = ?');
    my $success = defined $select_topic;
    my $rc = $Codestriker::OK;

    # Make sure that the topic still exists, and is therefore valid.
    $success &&= $select_topic->execute($self->{topicid});
    my ($current_version, $creation_ts);
    if ($success && 
	! (($current_version, $creation_ts) =
	   $select_topic->fetchrow_array())) {
	# Invalid topic id.
	$success = 0;
	$rc = $Codestriker::INVALID_TOPIC;
    }
    $success &&= $select_topic->finish();

    # Check the version number.
    if ($success && $self->{version} != $current_version) {
	$success = 0;
	$rc = $Codestriker::STALE_VERSION;
    }

    # Get the modified date to the current time.
    my $modified_ts = Codestriker->get_timestamp(time);

    # Map the new state to its number.
    my $new_stateid;
    for ($new_stateid = 0; $new_stateid <= $#Codestriker::topic_states;
	 $new_stateid++) {
	last if ($Codestriker::topic_states[$new_stateid] eq $new_state);
    }
    if ($new_stateid > $#Codestriker::topic_states) {
	die "Unable to change topic to invalid state: \"$new_state\"";
    }

    # Update the topic object's properties.
    $self->{title} = $new_title;
    $self->{author} = $new_author;
    $self->{repository} = $new_repository;
    $self->{project_id} = $new_projectid;
    $self->{description} = $new_description;
    $self->{modified_ts} = $modified_ts;
    $self->{topic_state} = $new_state;
    $self->{topic_state_id} = $new_stateid;

    # Now update the database with the new properties.  Note due to a weird
    # MySQL bug, we need to also retrieve the creation_ts and store
    # the same value when updating the record, otherwise it gets set to the
    # current time!
    my $update_topic =
	$dbh->prepare_cached('UPDATE topic SET version = ?, state = ?, ' .
			     'creation_ts = ?, modified_ts = ?, ' .
			     'title = ?, author = ?, ' .
			     'repository = ?, projectid = ?, ' .
			     'description = ? WHERE id = ?');
    $success &&= defined $update_topic;

    # If the state hasn't changed, don't do anything, otherwise update the
    # topic.
    if ($success) {
    	$self->{version} = $self->{version} + 1;
	$success &&= $update_topic->execute($self->{version}, $new_stateid,
					    $creation_ts, $modified_ts,
					    $new_title, $new_author,
					    $new_repository, $new_projectid,
					    $new_description,
					    $self->{topicid});
    }

    # Now delete all bugs associated with this topic, and recreate them again
    # if they have changed.
    if ($success && $self->{bug_ids} ne $new_bug_ids) {
	$success &&= $self->_delete_bug_ids($dbh);
	$success &&= $self->_insert_bug_ids($dbh, $new_bug_ids);
	$self->{bug_ids} = $new_bug_ids;
    }

    # Now delete all reviewers associated with this topic, and recreate
    # them again, if they have changed.
    if ($success && $self->{reviewers} ne $new_reviewers) {
	$success &&=
	    $self->_delete_participants($dbh,
					$Codestriker::PARTICIPANT_REVIEWER);
	$success &&=
	    $self->_insert_participants($dbh,
					$Codestriker::PARTICIPANT_REVIEWER,
					$new_reviewers, $modified_ts);
	$self->{reviewers} = $new_reviewers;
    }

    # Now delete all CCs associated with this topic, and recreate
    # them again, if they have changed.
    if ($success && $self->{cc} ne $new_cc) {
	$success &&=
	    $self->_delete_participants($dbh, $Codestriker::PARTICIPANT_CC);
	$success &&=
	    $self->_insert_participants($dbh, $Codestriker::PARTICIPANT_CC,
					$new_cc, $modified_ts);
	$self->{cc} = $new_cc;
    }
	
    Codestriker::DB::DBI->release_connection($dbh, $success);

    if ($success == 0 && $rc == $Codestriker::OK) {
	# Unexpected DB error.
	die $dbh->errstr;
    }

    return $rc;
}

# Return back the list of topics which match the specified parameters.
sub query($$$$$$$$$$$$$\@\@\@\@\@\@\@\@\@) {
    my ($type, $sauthor, $sreviewer, $scc, $sbugid, $sstate, $sproject, $stext,
	$stitle, $sdescription, $scomments, $sbody, $sfilename,
	$id_array_ref, $title_array_ref,
	$author_array_ref, $creation_ts_array_ref, $state_array_ref,
	$bugid_array_ref, $email_array_ref, $type_array_ref,
	$version_array_ref) = @_;

    # Obtain a database connection.
    my $dbh = Codestriker::DB::DBI->get_connection();

    # If there are wildcards in the author, reviewer or CC fields, replace
    # them with the appropriate SQL wildcards.
    $sauthor =~ s/\*/%/g if $sauthor ne "";
    $sreviewer =~ s/\*/%/g if $sreviewer ne "";
    $scc =~ s/\*/%/g if $scc ne "";

    # Build up the query conditions.
    my $author_part = $sauthor ne "" ? "topic.author LIKE ?" : "";
    my $reviewer_part = $sreviewer ne "" ?
	"participant.email LIKE ? AND " .
	"type = $Codestriker::PARTICIPANT_REVIEWER" : "";
    my $cc_part = $scc ne "" ?
	"participant.email LIKE ? AND type = $Codestriker::PARTICIPANT_CC" : "";
    my $bugid_part = $sbugid ne "" ? "topicbug.bugid = ?" : "";

    # Build up the state condition.
    my @state_values;
    my $state_part = "";
    if ($sstate ne "") {
	@state_values = split ',', $sstate;
	my $state_set = $sstate;
	$state_set =~ s/\d+/\?/g;
	$state_part = "topic.state IN ($state_set)";
    }

    # Build up the project condition.
    my @project_values;
    my $project_part = "";
    if ($sproject ne "") {
	@project_values = split ',', $sproject;
	my $project_set = $sproject;
	$project_set =~ s/\d+/\?/g;
	$project_part = "topic.projectid IN ($project_set)";
    }

    my $text_title_part = "lower(topic.title) LIKE ?";
    my $text_description_part = "lower(topic.description) LIKE ?";
    my $text_body_part = "lower(topic.document) LIKE ?";
    my $text_filename_part = "lower(topicfile.filename) LIKE ?";
    my $text_comment_part = "lower(commentdata.commentfield) LIKE ?";

    # Build up the base query.
    my $query =
	"SELECT topic.id, topic.title, topic.author, topic.creation_ts, " .
	"topic.state, topicbug.bugid, participant.email, participant.type, " .
	"topic.version " .
	"FROM topic LEFT OUTER JOIN topicbug ON topic.id = topicbug.topicid " .
	"LEFT OUTER JOIN participant ON topic.id = participant.topicid ";

    # Join with the comment table if required - GACK!
    if ($stext ne "" && $scomments) {
	$query .= 'LEFT OUTER JOIN commentstate ON ' .
	    'topic.id = commentstate.topicid LEFT OUTER JOIN commentdata ON ' .
	    'commentstate.id = commentdata.commentstateid ';
    }

    # Join with the file table if required.
    if ($stext ne "" && $sfilename) {
	$query .= 'LEFT OUTER JOIN topicfile ON topicfile.topicid = topic.id ';
    }

    # Combine the "AND" conditions together.
    my $first_condition = 1;
    my @values = ();
    $query = _add_condition($query, $author_part, $sauthor, \@values,
			    \$first_condition);
    $query = _add_condition($query, $reviewer_part, $sreviewer, \@values,
			    \$first_condition);
    $query = _add_condition($query, $cc_part, $scc, \@values,
			    \$first_condition);
    $query = _add_condition($query, $bugid_part, $sbugid, \@values,
			    \$first_condition);

    # Handle the state set.
    if ($state_part ne "") {
	$query = _add_condition($query, $state_part, undef, \@values,
				\$first_condition);
	push @values, @state_values;
    }

    # Handle the project set.
    if ($project_part ne "") {
	$query = _add_condition($query, $project_part, undef, \@values,
				\$first_condition);
	push @values, @project_values;
    }

    # Handle the text searching part, which can be a series of ORs.
    if ($stext ne "") {
	$stext =~ tr/[A-Z]/[a-z]/; # make it lower case.
	my @text_cond = ();
	my @text_values = ();
	push @text_cond, $text_title_part if $stitle;
	push @text_cond, $text_description_part if $sdescription;
	push @text_cond, $text_body_part if $sbody;
	push @text_cond, $text_filename_part if $sfilename;
	push @text_cond, $text_comment_part if $scomments;

	if ($#text_cond >= 0) {
	    my $cond = join  ' OR ', @text_cond;
	    $query = _add_condition($query, $cond, undef,
				    \@values, \$first_condition);
	    for (my $i = 0; $i <= $#text_cond; $i++) {
		# Replace '*' wildcards with SQL wildcards, and make sure the
		# expression is wildcard-wrapped given this is a "contains"
		# text search term.
		my $wildcard = $stext;
		$wildcard =~ s/\*/%/g;
		if (! ($wildcard =~ /^%/o) ) {
		    $wildcard = "%${wildcard}";
		}
		if (! ($wildcard =~ /%$/o) ) {
		    $wildcard = "${wildcard}%";
		}
		push @values, $wildcard;
	    }
	}
    }

    # Order the result by the creation date field.
    $query .= " ORDER BY topic.creation_ts ";

    my $select_topic = $dbh->prepare_cached($query);
    my $success = defined $select_topic;
    $success &&= $select_topic->execute(@values);
    if ($success) {
	my ($id, $title, $author, $creation_ts, $state, $bugid, $email, $type,
	    $version);
	while (($id, $title, $author, $creation_ts, $state, $bugid,
		$email, $type, $version) = $select_topic->fetchrow_array()) {
	    push @$id_array_ref, $id;
	    push @$title_array_ref, $title;
	    push @$author_array_ref, $author;
	    push @$creation_ts_array_ref, $creation_ts;
	    push @$state_array_ref, $state;
	    push @$bugid_array_ref, $bugid;
	    push @$email_array_ref, $email;
	    push @$type_array_ref, $type;
	    push @$version_array_ref, $version;
	}
	$select_topic->finish();
    }

    Codestriker::DB::DBI->release_connection($dbh, $success);
    die $dbh->errstr unless $success;
}

# Add the condition to the specified query string, returning the new query.
sub _add_condition($$$\@\$) {
    my ($query, $condition, $value, $values_array_ref, $first_cond_ref) = @_;

    return $query if ($condition eq ""); # Nothing to do.
    if ($$first_cond_ref) {
	$$first_cond_ref = 0;
	$query .= " WHERE (" . $condition . ") ";
    } else {
	$query .= " AND (" . $condition . ") ";
    }
    push @$values_array_ref, $value if defined $value;
    return $query;
}

# Delete the specified topic.
sub delete($) {
    my ($self) = @_;

    # Obtain a database connection.
    my $dbh = Codestriker::DB::DBI->get_connection();

    # Create the prepared statements.
    my $delete_topic = $dbh->prepare_cached('DELETE FROM topic WHERE id = ?');
    my $select = $dbh->prepare_cached('SELECT id FROM commentstate ' .
				      'WHERE topicid = ?');
    my $delete_comments =
	$dbh->prepare_cached('DELETE FROM commentdata ' .
			     'WHERE commentstateid = ?');
    my $delete_commentstate =
	$dbh->prepare_cached('DELETE FROM commentstate ' .
			     'WHERE topicid = ?');
    my $delete_file =
	$dbh->prepare_cached('DELETE FROM topicfile WHERE topicid = ?');

    my $delete_delta =
	$dbh->prepare_cached('DELETE FROM delta WHERE topicid = ?');

    my $topic_metrics =
	$dbh->prepare_cached('DELETE FROM topicmetric WHERE topicid = ?');

    my $user_metrics =
	$dbh->prepare_cached('DELETE FROM topicusermetric WHERE topicid = ?');

    my $topic_history =
	$dbh->prepare_cached('DELETE FROM topichistory WHERE topicid = ?');

    my $topic_view_history =
	$dbh->prepare_cached('DELETE FROM topicviewhistory WHERE topicid = ?');

    my $commentstate_history =
	$dbh->prepare_cached('DELETE FROM commentstatehistory WHERE id = ?');

    my $success = defined $delete_topic && defined $delete_comments &&
	defined $delete_commentstate && defined $select &&
	defined $delete_file && defined $delete_delta && 
	defined $topic_metrics && defined $user_metrics &&
	defined $topic_history && defined $topic_view_history &&
	defined $commentstate_history;

    # Now do the deed.
    $success &&= $select->execute($self->{topicid});
    if ($success) {
	while (my ($commentstateid) = $select->fetchrow_array()) {
	    $success &&= $delete_comments->execute($commentstateid);
	    $success &&= $commentstate_history->execute($commentstateid);
	}
	$success &&= $select->finish();
    }
    $success &&= $delete_commentstate->execute($self->{topicid});
    $success &&= $delete_topic->execute($self->{topicid});
    $success &&= $delete_comments->execute($self->{topicid});
    $success &&= $delete_file->execute($self->{topicid});
    $success &&= $delete_delta->execute($self->{topicid});
    $success &&= $topic_metrics->execute($self->{topicid});
    $success &&= $user_metrics->execute($self->{topicid});
    $success &&= $self->_delete_bug_ids($dbh);
    $success &&=
	$self->_delete_participants($dbh, $Codestriker::PARTICIPANT_REVIEWER);
    $success &&=
	$self->_delete_participants($dbh, $Codestriker::PARTICIPANT_CC);
    $success &&= $topic_history->execute($self->{topicid});
    $success &&= $topic_view_history->execute($self->{topicid});

    Codestriker::DB::DBI->release_connection($dbh, $success);

    # Indicate the success of the operation.
    return $success ? $Codestriker::OK : $Codestriker::INVALID_TOPIC;
}

1;
