#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use Encode;
use Data::Dumper;
use FindBin;
use Try::Tiny;
use Getopt::Std;
use Text::Xslate;
use File::Copy::Recursive qw(rcopy);
use Text::MediawikiFormat qw(wikiformat);
use XML::FeedPP;
use DateTime::Format::W3CDTF;
use Log::Log4perl;

my $logfile = $FindBin::Bin . '/hulu-website.log';
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

my %opts = ();
getopts('p:', \%opts);

sub create_static_files {
    my $out_dir = $FindBin::Bin . '/website';
    mkdir $out_dir;

    my @dirs = qw(css js img favicon.ico);
    for my $d (@dirs) {
        rcopy $FindBin::Bin . "/website-template/$d", "$out_dir/$d";
    }
}

sub create_rss {
    my ($latest_bands) = @_;

    my $rss = XML::FeedPP::RSS->new;
    my $appname = '夏フェス 更新情報';
    my $base_url = 'http://summerfes.band-local.net/';
    my $description = '夏フェスの更新情報を纏める非公式サイトです。';
    $rss->language('ja-JP');
    $rss->title($appname);
    $rss->link($base_url);
    $rss->description($description);
    $rss->pubDate(DateTime::Format::W3CDTF->format_datetime(DateTime->now(time_zone => 'local')));
    $rss->image(
        "${base_url}img/summerfes.png",
        $appname,
        $base_url,
        $description,
    );

    for my $b (@$latest_bands) {
        my $name = decode_utf8($b->{name});
        print Dumper $b;
        $rss->add_item(
          title       => $name,
          link        => "http://summerfes.band-local.net/",
          description => "$name が $b->{date} に $b->{fes_name} に出演します。",
        );
    }
    mkdir $FindBin::Bin . '/website';
    $rss->to_file($FindBin::Bin . '/website/rss.xml');
}

sub create_index_page {
    my ($latest_bands, $all_bands) = @_;

    my $tx = Text::Xslate->new(path => $FindBin::Bin);

    my $data = {
        latest_bands => $latest_bands,
        all_bands => $all_bands,
    };
    mkdir $FindBin::Bin . '/website';
    my $content = $tx->render('website-template/index.tx.html', $data);
    my $out_file = $FindBin::Bin . '/website/index.html';
    open my $out_fh, ">", $out_file
        or die "Cannot open $out_file for write: $!";
    print $out_fh encode_utf8($content);
    close $out_fh;
}

try {
    use DBI;
    my $dbh = DBI->connect('dbi:SQLite:dbname=' . $FindBin::Bin . '/feses.db', "", "", {PrintError => 1, AutoCommit => 1});

    # latest_bands
    my $sth = $dbh->prepare(q{
        select b.*, l.name as location_name, f.name as fes_name from bands as b
        inner join locations as l on l.id = b.location_id
        inner join feses as f on f.id = l.fes_id
        where b.created_at > date('now', '-3 days', 'localtime')
        order by b.created_at desc
        limit 100
    });
    $sth->execute;

    my @latest_bands = ();
    while (my $row = $sth->fetchrow_hashref()){
        my $path = $row->{url};
        $path =~ s{.*\/(.*)$}{$1};
        $row->{path} = $path;
        push @latest_bands, $row;
    }
    die $sth->errstr if $sth->err;

    # all_bands
    $sth = $dbh->prepare(q{
        select b.*, l.name as location_name, f.name as fes_name from bands as b
        inner join locations as l on l.id = b.location_id
        inner join feses as f on f.id = l.fes_id
        where b.updated_at > date('now' , '-1 days' )
        order by f.id, l.id, b.name
    });
    $sth->execute;

    my @all_bands = ();
    my $last_index = '';
    while (my $row = $sth->fetchrow_hashref()){
        my $path = $row->{url};
        $path =~ s{.*\/(.*)$}{$1};
        $row->{path} = $path;
        my $index = substr $row->{title}, 0, 1;
        if ($index ne $last_index) {
            $row->{index} = $index;
            $last_index = $index;
        }
        push @all_bands, $row;
    }
    die $sth->errstr if $sth->err;
    print scalar @all_bands;

    create_static_files;

    create_rss(\@latest_bands);
    create_index_page(\@latest_bands, \@all_bands);

    $dbh->disconnect;
} catch {
    $logger->error_die("caught error: $_");
};
$logger->info('finished cleanly.');

__END__

create table videos (id integer primary key, url varchar, title varchar, seasons integer, episodes integer, created_at datetime, updated_at datetime);
create table updates (id integer primary key, video_id integer not null, is_new integer not null, seasons integer, episodes integer, created_at datetime, updated_at datetime);

