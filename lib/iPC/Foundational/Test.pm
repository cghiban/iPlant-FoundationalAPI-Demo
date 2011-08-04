package iPC::Foundational::Test;
use Dancer ':syntax';

use lib '/home/cornel/work/iPlant-FoundationalAPI/lib';

use iPlant::FoundationalAPI ();
use Data::Dumper;

our $VERSION = '0.1';

sub token_valid {
	my $tk_expiration = session('token_expiration');
	
	# if we don't have an expiration token
	return 1 unless $tk_expiration;
	# else
	print STDERR "DELTA: ", $tk_expiration - time(), $/;
	return $tk_expiration > time();
}

get '/' => sub {
    template 'index';
};

get '/logout' => sub {
	#session username => '';
	session 'token' => '';
	session 'logged_in' => 0;

	return redirect '/';
};

any ['get', 'post'] => '/login' => sub {
	
	my $err = "";

	if ( request->method() eq "POST" ) {
		if ( params->{'username'} eq "") {
			$err .= "Username is missing";
		}
		my $apif = iPlant::FoundationalAPI->new(
						user => params->{'username'},
						password => params->{'password'},
					);
		if ($apif->token) {
			debug "Token: " . $apif->token . "\n";
			session 'username' => params->{'username'};
			session 'token' => $apif->token;
			session 'token_expiration' => $apif->token_expiration;
			session 'logged_in' => 1;

			#print STDERR  'token_expiration: ', session('token_expiration'), $/;
			#print STDERR  'time: ', time(), $/;

			#set_flash("You're logged in.");

			return redirect "/browse/";
		}
		else {
			$err .= "Invalid credentials."
		}
	}

    template 'login', {
		err => $err,
		username => params->{'username'} ? params->{'username'} : session("username"),
	};
	
};


get qr{/browse/?(.*)} => sub {
	unless(session('logged_in') && token_valid()) {
		return redirect '/login';
	}

	my $username = session('username');
	my $apif = iPlant::FoundationalAPI->new(
					user => $username,
					token => session('token'),
				);

	my ($path) = splat;
	my $path_to_read = $path ? $path : $username;
	print STDERR  "PATH: $path_to_read", $/;
	$path_to_read = '/' . $path_to_read unless $path_to_read =~ m|^/|;
	print STDERR  "PATH: $path_to_read", $/;

	my $io = $apif->io;
	my $dir_list = $io->readdir($path_to_read);

	print STDERR Dumper($dir_list);

	template 'browse', {
		path => $path_to_read,
		list => $dir_list,
	};
};

get qr{/xbrowse/?(.*)} => sub {
	unless(session('logged_in') && token_valid()) {
		return halt("[]");
	}

	my $username = session('username');
	my $apif = iPlant::FoundationalAPI->new(
					user => $username,
					token => session('token'),
				);

	my ($path) = splat;
	my $path_to_read = $path ? $path : $username;
	#print STDERR  "PATH: $path_to_read", $/;
	$path_to_read = '/' . $path_to_read unless $path_to_read =~ m|^/|;
	#print STDERR  "PATH: $path_to_read", $/;

	my $io = $apif->io;
	my $dir_list = $io->readdir($path_to_read);
	set serializer => 'JSON';

	return $dir_list;
};

get qr{/apps/?} => sub {
	unless(session('logged_in') && token_valid()) {
		return redirect '/login';
	}

	my $username = session('username');
	my $apif = iPlant::FoundationalAPI->new(
					user => $username,
					token => session('token'),
				);

	my $apps = $apif->apps;
	my $app_list = $apps->list;
	#print STDERR Dumper($app_list);

 	template 'apps', {
 		list => $app_list,
	};
};

get '/xapps/?' => sub {
	unless(session('logged_in') && token_valid()) {
		return halt("[]");
	}

	my $username = session('username');
	my $apif = iPlant::FoundationalAPI->new(
					user => $username,
					token => session('token'),
				);

	my $apps = $apif->apps;
	my $app_list = $apps->list;
	#print STDERR Dumper( $app_list->[0]->TO_JSON), $/;
	#print STDERR Dumper( $app_list ), $/;

	set serializer => 'JSON';

	return $app_list;
};

get '/app/:name' => sub {
	unless(session('logged_in') && token_valid()) {
		return redirect '/login';
	}

	my $apif = iPlant::FoundationalAPI->new(
					user => session('username'),
					token => session('token'),
				);

	my $apps = $apif->apps;
	my ($app) = $apps->find_by_name(param("name"));

	my ($inputs, $parameters) = ([], []);
	if ($app) {
		$inputs = $app->inputs;
		$parameters = $app->parameters;
	}
 	template 'app', {
 		app => $app,
		app_inputs => $inputs,
		app_params => $parameters,
		name => param("name"),
	};
};

get '/jobs/?' => sub {
	unless(session('logged_in') && token_valid()) {
		return redirect '/login';
	}

	my $username = session('username');
	my $apif = iPlant::FoundationalAPI->new(
					user => $username,
					token => session('token'),
				);

	my $job_ep = $apif->job;
	my $job_list = $job_ep->jobs;
	#print STDERR Dumper($app_list);

 	template 'jobs', {
 		list => $job_list,
	};
};

get '/job/:id' => sub {
	unless(session('logged_in') && token_valid()) {
		return redirect '/login';
	}

	my $job_id = param("id");
	my $username = session('username');
	my $apif = iPlant::FoundationalAPI->new(
					user => $username,
					token => session('token'),
				);

	my $job_ep = $apif->job;
	my $job = $job_ep->job_details($job_id);
	#print STDERR  'ST:', join ', ', localtime($job->{startTime}), $/;
	#print STDERR  'ET:', join ', ', localtime($job->{endTime}), $/;
	#print STDERR Dumper($job);

 	template 'job', {
 		job => $job,
		job_id => $job_id,
	};
};

get '/job/:id/remove' => sub {
	unless(session('logged_in') && token_valid()) {
		return redirect '/login';
	}

	my $job_id = param("id");
	my $username = session('username');
	my $apif = iPlant::FoundationalAPI->new(
					user => $username,
					token => session('token'),
				);

	my $job_ep = $apif->job;
	#my $job = $job_ep->job_details($job_id);
	my $st = $job_ep->delete_job($job_id);

	return redirect '/jobs';
	#template 'job', {
	#	job => $job,
	#	job_id => $job_id,
	#	msg =>  $st == 1 ? "Job removed." : "Unable to remove job.",
	#};
};

get '/job/new/:id' => sub {
	unless(session('logged_in') && token_valid()) {
		return redirect '/login';
	}

	my $app_id = param("id");
	my $username = session('username');
	my $apif = iPlant::FoundationalAPI->new(
					user => $username,
					token => session('token'),
				);

	my $apps = $apif->apps;

	my ($app) = $apps->find_by_name($app_id);

	my ($inputs, $parameters) = ([], []);
	if ($app) {
		$inputs = $app->inputs;
		$parameters = $app->parameters;
	}
 	template 'job_new', {
 		app => $app,
		app_inputs => $inputs,
		app_params => $parameters,
		name => $app_id,
	};
};


true;
