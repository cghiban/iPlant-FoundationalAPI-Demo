package iPC::Foundational::Test;
use Dancer ':syntax';

use Dancer::Plugin::MemcachedFast;
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


sub genomes  {
	
	{
		arabidopsis_lyrata => {
			sub_part => 'araly1',
			versions => [qw/v1.0/],
		},
		arabidopsis_thaliana => {
			sub_part => 'col-0',
			versions => [qw/v10 v9/],
		},
		brachypodium_distachyon => {
			sub_part => 'bd21',
			versions => [qw/v1.0/],
		},
		oryza_indica => {
			sub_part => 'bgi05',
			versions => [qw/v1.0/],
		},
		oryza_japonica => {
			sub_part => 'nipponbare',
			versions => [qw/v6/],
		},
		physcomitrella_patens => {
			sub_part => 'phypa1',
			versions => [qw/v1.1/],
		},
		populus_trichocarpa => {
			sub_part => 'nisqually1',
			versions => [qw/v2.0/],
		},
		sorghum_bicolor => {
			sub_part => 'bt623',
			versions => [qw/v1/],
		},
		vitis_vinifera => {
			sub_part => 'pn40024',
			versions => [qw/v12x/],
		},
		zea_mays => {
			sub_part => 'b73',
			versions => [qw/v5a v2 v1/],
		}
	};
};

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
			if ($apif->token ne "-1") {
				debug "Token: " . $apif->token . "\n";
				session 'username' => params->{'username'};
				session 'token' => $apif->token;
				session 'token_expiration' => $apif->token_expiration;
				session 'logged_in' => 1;

				#print STDERR  'token_expiration: ', session('token_expiration'), $/;
				#print STDERR  'time: ', time(), $/;

				#set_flash("You're logged in.");

				return redirect "/jsbrowse/";
			}
			else {
				$err .= "Can't login. System error.";
			}
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


get '/jiji1' => sub {

	unless(session('logged_in') && token_valid()) {
		return halt("[]");
	}

	my $username = session('username');

	my ($path) = splat;
	my $path_to_read = $path ? $path : $username;
	#print STDERR  "PATH: $path_to_read", $/;
	$path_to_read = '/' . $path_to_read unless $path_to_read =~ m|^/|;
	#print STDERR  "PATH: $path_to_read", $/;

	my $dir_list = [];

	my $dir_cache = memcached_get("dir-list-$username");
	print STDERR Dumper( $dir_list ), $/;
	if (defined $dir_cache->{$path_to_read} && $dir_cache->{$path_to_read} ) {
		print STDERR  "** getting from cache...", $/;
		$dir_list = $dir_cache->{$path_to_read};
	}
	else {
		print STDERR  "** getting from API...", $/;
		my $apif = iPlant::FoundationalAPI->new(
					user => $username,
					token => session('token'),
				);
		my $io = $apif->io;
		$dir_list = $io->readdir($path_to_read);
		$dir_cache->{$path_to_read} = $dir_list;

		memcached_set("dir-list-$username", $dir_cache);
	}

	set serializer => 'JSON';

	return $dir_list;
};

get '/jsbrowse/?:nocache?' => sub {
	unless(session('logged_in') && token_valid()) {
		return redirect '/login';
	}

	my $username = session('username');
# 	my $apif = iPlant::FoundationalAPI->new(
# 					user => $username,
# 					token => session('token'),
# 				);
	# 
 	my ($path) = splat;
 	my $path_to_read = $path ? $path : $username;
# 	print STDERR  "PATH: $path_to_read", $/;
 	$path_to_read = '/' . $path_to_read unless $path_to_read =~ m|^/|;
 	print STDERR  "PATH: $path_to_read", $/;
	# 
# 	my $io = $apif->io;
# 	my $dir_list = $io->readdir($path_to_read);
	# 
# 	print STDERR Dumper($dir_list);

	template 'jsbrowse', {
		path => $path_to_read,
		username => $username,
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

	#my $dir_cache = memcached_get("dir-list-$username");
	#$dir_cache->{$path_to_read} = $dir_list;
	#print STDERR "set new path in cache: $path_to_read ", memcached_set("dir-list-$username", $dir_cache), $/;
	#print STDERR Dumper( [keys %$dir_cache ]), $/;

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
	my $app_list = memcached_get_or_set ("apps-list-$username", sub { $apps->list;});
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
	#my $app_list = $apps->list;
	my $app_list = memcached_get_or_set ("apps-list-$username", sub { $apps->list;});
	#print STDERR Dumper( $app_list->[0]->TO_JSON), $/;
	#print STDERR Dumper( $app_list ), $/;

	set serializer => 'JSON';

	return $app_list;
};

get '/app/:name' => sub {
	unless(session('logged_in') && token_valid()) {
		return redirect '/login';
	}

	my $username = session('username');
	my $apif = iPlant::FoundationalAPI->new(
					user => $username,
					token => session('token'),
				);

	my $app_name = param("name");
	my $apps = $apif->apps;
	my ($app) = memcached_get_or_set ("app-$username-$app_name", sub { 
			my ($app) = $apps->find_by_name($app_name); 
			return $app;
		});
	print STDERR '$app = ', $app, $/;

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
	print STDERR Dumper($job);

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

any ['get', 'post'] => '/job/new/:id' => sub {
	unless(session('logged_in') && token_valid()) {
		return redirect '/login';
	}

	my @err = ();
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
	my $genomes = genomes();

	my $form = {};
	if ( request->method() eq "POST" ) {
		$form = params();
		#$form->{archive} = 1;

		# TODO - check arguments

		if (defined $form->{genome} && $form->{genome}) {
			my ($g, $v) = split '/', $form->{genome};
			$form->{genome} = "/shared/iplantcollaborative/genomeservices/legacy/0.30/genomes/" 
				. $g . "/" . $genomes->{ $g }->{sub_part} . '/' . $v . '/genome.fas';
			#print STDERR  "Genome: ", $form->{genome}, $/;
			if (grep {$_->{id} eq 'annotation'} @$inputs) {
				$form->{annotation} = "/shared/iplantcollaborative/genomeservices/legacy/0.30/genomes/" 
					. $g . "/" . $genomes->{ $g }->{sub_part} . '/' . $v . '/annotation.gtf';
				#print STDERR  "Annotation..: ", $form->{annotation}, $/;
			}
		}

		my $job_ep = $apif->job;
		my $job = $job_ep->submit_job($app, %$form);
		if ($job != -1) {
			#$job_id = $job->{id};
			return redirect '/job/' . $job->{id};
		}
		print STDERR Dumper( $form ), $/;
	}
 	template 'job_new', {
		errors => \@err,
 		app => $app,
		app_inputs => $inputs,
		app_params => $parameters,
		name => $app_id,
		genomes => $genomes,
		username => $username,
		form => $form,
	};
};



true;
