###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Main package which contains a reference to all configuration variables.

package Codestriker;

use strict;

use Time::Local;

# Export codestriker.conf configuration variables.
use vars qw ( $datadir $sendmail $use_compression $gzip $bugtracker
	      $cvsviewer $cvsrep $cvscmd $codestriker_css
	      $default_topic_create_mode $default_tabwidth
	      $db $dbuser $dbpasswd
	      $NORMAL_MODE $COLOURED_MODE $COLOURED_MONO_MODE $topic_states
	      $bug_db $bug_db_host $bug_db_name $bug_db_password $bug_db_user
	      $lxr_db $lxr_user $lxr_passwd $lxr_idlookup_base_url
	      );

# Version of Codestriker.
$Codestriker::VERSION = "1.5.5";

# Revision number constants used in the filetable with special meanings.
$Codestriker::ADDED_REVISION = "1.0";
$Codestriker::REMOVED_REVISION = "0.0";
$Codestriker::PATCH_REVISION = "0.1";

# Participant type constants.
$Codestriker::PARTICIPANT_REVIEWER = 0;
$Codestriker::PARTICIPANT_CC = 1;

# Default email context to use.
$Codestriker::EMAIL_CONTEXT = 8;

# Day strings
@Codestriker::days = ("Sunday", "Monday", "Tuesday", "Wednesday", "Thursday",
		      "Friday", "Saturday");

# Month strings
@Codestriker::months = ("January", "February", "March", "April", "May", "June",
			"July", "August", "September", "October", "November",
			"December");

# Short day strings
@Codestriker::short_days = ("Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat");

# Short month strings
@Codestriker::short_months = ("Jan", "Feb", "Mar", "Apr", "May", "Jun",
			      "Jul", "Aug", "Sep", "Oct", "Nov", "Dec");

# Initialise codestriker, by loading up the configuration file and exporting
# those values to the rest of the system.
sub initialise($) {
    my ($type) = @_;

    # Load up the configuration file.
    my $config = "../codestriker.conf";
    if (-f $config) {
	do $config;
    } else {
	die("Couldn't find configuration file: \"$config\".\n<BR>" .
	    "Please fix the \$config setting in codestriker.pl.");
    }
}

# Returns the current time in a format suitable for a DBI timestamp value.
sub get_timestamp($$) {
    my ($type, $time) = @_;
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =
	localtime($time);
    $year += 1900;

    return sprintf("%04d-%02d-%02d %02d:%02d:%02d", $year, $mon+1, $mday,
		   $hour, $min, $sec);
}

# Given a database formatted timestamp, output it in a human-readable form.
sub format_timestamp($$) {
    my ($type, $timestamp) = @_;

    if ($timestamp =~ /(\d\d\d\d)\-(\d\d)\-(\d\d) (\d\d):(\d\d):(\d\d)/ ||
	$timestamp =~ /(\d\d\d\d)(\d\d)(\d\d)(\d\d)(\d\d)(\d\d)/) {
	my $time_value = Time::Local::timelocal($6, $5, $4, $3, $2-1, $1);
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =
	    localtime($time_value);
	$year += 1900;
	return sprintf("%02d:%02d:%02d $Codestriker::days[$wday], $mday " .
		       "$Codestriker::months[$mon], $year",
		       $hour, $min, $sec);
    } else {
	return $timestamp;
    }
}

# Given a database formatted timestamp, output it in a short,
# human-readable form.
sub format_short_timestamp($$) {
    my ($type, $timestamp) = @_;

    if ($timestamp =~ /(\d\d\d\d)\-(\d\d)\-(\d\d) (\d\d):(\d\d):(\d\d)/ ||
	$timestamp =~ /(\d\d\d\d)(\d\d)(\d\d)(\d\d)(\d\d)(\d\d)/) {
	my $time_value = Time::Local::timelocal($6, $5, $4, $3, $2-1, $1);
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =
	    localtime($time_value);
	$year += 1900;
	return sprintf("%02d:%02d:%02d $Codestriker::short_days[$wday], " .
		       "$mday $Codestriker::short_months[$mon], $year",
		       $hour, $min, $sec);
    } else {
	return $timestamp;
    }
}

1;

