###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Action object for displaying the topic search page.

package Codestriker::Action::ViewSearch;

use strict;

# Create an appropriate form for topic searching.
sub process($$$) {
    my ($type, $http_input, $http_response) = @_;

    my $query = $http_response->get_query();
    $http_response->generate_header("", "Search", "", "", "", "", "", "", 0, 0);

    # Create the hash for the template variables.
    my $vars = {};

    # Create the list of valid states that can be searched over.
    my @states = ("Any");
    push @states, @Codestriker::topic_states;
    $vars->{'states'} = \@states;

    my $template = Codestriker::Http::Template->new("search");
    $template->process($vars) || die $template->error();
}

1;