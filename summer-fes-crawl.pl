#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use LWP;
use Encode;
use Net::Twitter;
use Data::Dumper;
use FindBin;
use Try::Tiny;
use Getopt::Std;
use List::Compare;
use Config::Simple;
use Web::Query;

use Log::Log4perl;
# my $config = new Config::Simple($FindBin::Bin . '/twitter.conf');

my $logfile = $FindBin::Bin . '/summer-fes-crawl.log';
my $conf = qq(
    log4perl.logger.main          = DEBUG, Logfile, Screen

    log4perl.appender.Logfile          = Log::Log4perl::Appender::File
    log4perl.appender.Logfile.filename = $logfile
    log4perl.appender.Logfile.layout   = Log::Log4perl::Layout::PatternLayout
    log4perl.appender.Logfile.layout.ConversionPattern = [%d] %F %L %m%n

    log4perl.appender.Screen         = Log::Log4perl::Appender::Screen
    log4perl.appender.Screen.stderr  = 0
    log4perl.appender.Screen.layout = Log::Log4perl::Layout::SimpleLayout
);
Log::Log4perl->init(\$conf);
my $logger = Log::Log4perl->get_logger('main');

my $feses = {
    "FUJI ROCK FESTIVAL '13" => {
        locations => {
            '新潟県 湯沢町 苗場スキー場' => {
                id => 1,
                lineup_page => 'http://www.fujirockfestival.com/artist/',
                days => {
                    '2013/7/26' => [],
                    '2013/7/27' => [],
                    '2013/7/28' => [],
                },
            },
        },
    },
    'SUMMER SONIC 2013' => {
        locations => {
            '東京' => {
                id => 2,
                lineup_page => 'http://www.summersonic.com/2013/lineup/index.html',
                days => {
                    '2013/8/10' => [],
                    '2013/8/11' => [],
                },
            },
            '大阪' => {
                id => 3,
                lineup_page => 'http://www.summersonic.com/2013/lineup/osaka.html',
                days => {
                    '2013/8/10' => [],
                    '2013/8/11' => [],
                },
            },
        },
    },
};

my %opts = ();
getopts('p:', \%opts);

my $checked_date = DateTime->now->epoch;

# sub twitter_post {
#     my ($message) = @_;
# 
#     $message .= ' http://hulu-update.info/';
#     $logger->info(encode_utf8($message));
#     my $nt = Net::Twitter->new(
#         traits   => [qw/OAuth API::REST/],
#         consumer_key => $config->param('consumer_key'),
#         consumer_secret => $config->param('consumer_secret'),
#         access_token => $config->param('access_token'),
#         access_token_secret => $config->param('access_token_secret'),
#     );
# 
#     if (defined $opts{p} && $opts{p} eq 'true') {
#         $nt->update($message) or die $@;
#     } else {
#         $logger->debug('not post.');
#     }
# }
# 
# sub last_checked_date {
#     my ($dbh) = @_;
#     my $rows = $dbh->do('');
#     my $sth = $dbh->prepare(q{select max(checked_date) as last_checked_date from published_videos});
#     $sth->execute or die 'failed to select. url';
#     return $sth->fetchrow_hashref->{last_checked_date};
# }
# 
# sub deleted_video {
#     my ($row) = @_;
# 
#     my $response = LWP::UserAgent->new->request(HTTP::Request->new(GET => $row->{url}));
#     return $response->status_line =~ m{404};
# }
# 
# sub check_deleted_videos {
#     my ($dbh, $last_checked_date, $checked_date) = @_;
#     my $rows = $dbh->selectall_arrayref(q{
#         select v.id
#         from published_videos as p
#         inner join videos as v on v.id = p.video_id
#         where p.checked_date = ?
#     }, {Slice => {}}, $last_checked_date);
#     my @last_videos = ();
#     for my $r (@$rows) {
#         push @last_videos, $r->{id};
#     }
#     $rows = $dbh->selectall_arrayref(q{
#         select v.id
#         from published_videos as p
#         inner join videos as v on v.id = p.video_id
#         where p.checked_date = ?
#     }, {Slice => {}}, $checked_date);
#     my @new_videos = ();
#     for my $r (@$rows) {
#         push @new_videos, $r->{id};
#     }
#     print 'last_videos: ', scalar @last_videos, "\n";
#     print 'new_videos: ', scalar @new_videos, "\n";
# 
#     my $lc = List::Compare->new(\@last_videos, \@new_videos);
#     for my $id ($lc->get_Lonly) {
#         my $row = $dbh->selectrow_hashref(q{
#             select * from videos where id = ?
#         }, {Slice => {}}, $id);
#         print "deleted $id: ", $row->{title}, "\n";
#         next unless deleted_video($row);
# 
#         my $sth = $dbh->prepare(q{insert into updates (video_id, is_new, seasons, episodes, created_at, updated_at) values (?, 0, ?, ?, datetime('now', 'localtime'), datetime('now', 'localtime'))});
#         $sth->execute(
#             $id,
#             0,
#             0,
#         ) or die 'failed to insert. id:' . $id;
#         $sth = $dbh->prepare(q{update videos set seasons = ?, episodes = ?, updated_at = datetime('now', 'localtime') where id = ?});
#         $sth->execute(
#             0,
#             0,
#             $id,
#         ) or die 'failed to update. id:' . $id;
#         my $message = '[' . decode_utf8($row->{title}) . '] が削除されました。' . $row->{url};
#         $logger->info(encode_utf8($message));
#         twitter_post($message);
#     }
# }

$Web::Query::UserAgent = LWP::UserAgent->new( agent => 'Mozilla/5.0' );

sub fetch_fujirock {
    my $location = $feses->{"FUJI ROCK FESTIVAL '13"}->{locations}->{'新潟県 湯沢町 苗場スキー場'};
    wq($location->{lineup_page})
        # 2013/7/26
        ->find('div#listingFri .rightArtists img')
        ->each(sub {
            push $location->{days}->{'2013/7/26'}, {id => $_->parent->attr('href'), name => $_->attr('alt')};
        })
        ->end
        ->find('div#listingFri .listingArea li a')
        ->each(sub{
            push $location->{days}->{'2013/7/26'}, {id => $_->attr('href'), name => $_->text};
        })
        ->end
        # 2013/7/27
        ->find('div#listingSat .rightArtists img')
        ->each(sub {
            push $location->{days}->{'2013/7/27'}, {id => $_->parent->attr('href'), name => $_->attr('alt')};
        })
        ->end
        ->find('div#listingSat .listingArea li a')
        ->each(sub{
            push $location->{days}->{'2013/7/27'}, {id => $_->attr('href'), name => $_->text};
        })
        ->end
        # 2013/7/28
        ->find('div#listingSun .rightArtists img')
        ->each(sub {
            push $location->{days}->{'2013/7/28'}, {id => $_->parent->attr('href'), name => $_->attr('alt')};
        })
        ->end
        ->find('div#listingSun .listingArea li a')
        ->each(sub{
            push $location->{days}->{'2013/7/28'}, {id => $_->attr('href'), name => $_->text};
        })
    ;
}

sub fetch_summersonic {
    my $location = $feses->{'SUMMER SONIC 2013'}->{locations}->{'東京'};
    wq($location->{lineup_page})
        # 2013/8/10
        ->find('ul#list810 a img')
        ->each(sub {
            push $location->{days}->{'2013/8/10'}, {id => $_->attr('src'), name => $_->attr('alt')};
        })
        ->end
        # 2013/7/27
        ->find('ul#list811 a img')
        ->each(sub {
            push $location->{days}->{'2013/8/11'}, {id => $_->attr('src'), name => $_->attr('alt')};
        })
        ->end
    ;

    $location = $feses->{'SUMMER SONIC 2013'}->{locations}->{'大阪'};
    wq($location->{lineup_page})
        # 2013/8/10
        ->find('ul#list810 a img')
        ->each(sub {
            push $location->{days}->{'2013/8/10'}, {id => $_->attr('src'), name => $_->attr('alt')};
        })
        ->end
        # 2013/7/27
        ->find('ul#list811 a img')
        ->each(sub {
            push $location->{days}->{'2013/8/11'}, {id => $_->attr('src'), name => $_->attr('alt')};
        })
        ->end
    ;
}

try {
    # fujirock
    fetch_fujirock;
    # summer sonic
    fetch_summersonic;

    use DBI;
    my $dbh = DBI->connect('dbi:SQLite:dbname=' . $FindBin::Bin . '/feses.db', "", "", {PrintError => 1, AutoCommit => 1});

    my $select = "select * from bands where location_id = ? and local_id = ?";
    my $sth = $dbh->prepare($select);
    my $sth_insert = $dbh->prepare(q{insert into bands (location_id, local_id, name, date, created_at, updated_at, deleted) values (?, ?, ?, ?, datetime('now', 'localtime'), datetime('now', 'localtime'), 0)});
    my $sth_update = $dbh->prepare(q{update bands set local_id = ?, name = ?, date = ?, updated_at = datetime('now', 'localtime') where id = ?});

    while (my ($fes_name, $fes) = each %$feses) {
        while (my ($location_name, $location) = each %{$fes->{locations}}) {
            while (my ($date, $bands) = each %{$location->{days}}) {
                foreach my $band (@$bands) {
                    print encode_utf8 $band->{name}, "\n";
                    $sth->execute($location->{id}, $band->{id});
                    my $already_registered_band = $sth->fetchrow_hashref;
                    if ($already_registered_band) {
                        #update
                        my $id = $already_registered_band->{id};
                        $sth_update->execute(
                            $band->{id},
                            $band->{name},
                            $date,
                            $already_registered_band->{id},
                        ) or die 'failed to update. url:' . $band->{name};
                    } else {
                        #insert
                        $sth_insert->execute(
                            $location->{id},
                            $band->{id},
                            $band->{name},
                            $date,
                        ) or die 'failed to insert. url:' . $band->{name};
                    }
                }
            }
        }
    }
    $sth->finish;
    $sth_insert->finish;
    $sth_update->finish;
    $dbh->disconnect;
} catch {
    $logger->error_die("caught error: $_");
};
$logger->info('finished cleanly.');

__END__

create table feses (id integer primary key, name varchar, created_at datetime, updated_at datetime);
insert into feses (id, name, created_at, updated_at) values(1, 'FUJI ROCK FESTIVAL ''13', current_timestamp, current_timestamp);
insert into feses (id, name, created_at, updated_at) values(2, 'SUMMER SONIC 2013', current_timestamp, current_timestamp);
create table locations (id integer primary key, fes_id integer, name varchar, lineup_page varchar, created_at datetime, updated_at datetime);
insert into locations (id, fes_id, name, lineup_page, created_at, updated_at) values(1, 1, '新潟県 湯沢町 苗場スキー場', 'http://www.fujirockfestival.com/artist/', current_timestamp, current_timestamp);
insert into locations (id, fes_id, name, lineup_page, created_at, updated_at) values(2, 2, '東京', 'http://www.summersonic.com/2013/lineup/index.html', current_timestamp, current_timestamp);
insert into locations (id, fes_id, name, lineup_page, created_at, updated_at) values(3, 2, '大阪', 'http://www.summersonic.com/2013/lineup/osaka.html', current_timestamp, current_timestamp);
create table bands (id integer primary key, location_id integer, date varchar, name varchar, local_id varchar, created_at datetime, updated_at datetime, deleted);

