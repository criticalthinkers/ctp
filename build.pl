#!/usr/bin/perl

use strict;
use warnings;

build();

sub build {
    my $outdir = "./site";
    my $herokuserver = "https://criticalthinking.herokuapp.com";
    my %article_index_lists = ();
    my %all_tags = ();
    my %tagcloud_class_lookup;
    my $saw_first_essay_for_index = 0;
    my $continue_processing_index = 1;
    my $main_index_content;
    my $tagcloud = "";

    $main_index_content = read_as_string("./template/index", 1);

    `rm -rf $outdir`;
    `mkdir $outdir`;

    foreach (split /\n/, `find . -regex "\./[a-z]+/[0-9]+-.*" | sort -nr -t "/" -k3`) {
        my $filepath = $_;
        my ($dot, $sectionname, $articlename) = split /\//, $filepath;
        my %lookup = ();
        my $data;
        my $list;
        my $fill;

        $data = read_as_string($filepath, 1);

        $lookup{filepath} = $filepath;
        $lookup{filename} = substr($articlename, length("yyyymmdd-")) . ".html";
        $lookup{section} = $sectionname;
        $lookup{pageurl} = "$herokuserver/$sectionname/$lookup{filename}";
        $lookup{$1} = $2 while ($data =~ /<(\w+)>(.+?)<\/\1>/g);

        if (exists $article_index_lists{$sectionname}) {
            $list = $article_index_lists{$sectionname};
        } else {
            `mkdir $outdir/$sectionname`;
            $list = "";
        }
        $list .= fill($filepath, "./template/" . $sectionname . "_item", \%lookup);
        $article_index_lists{$sectionname} = $list;

        if (exists $lookup{tags}) {
            foreach (split /,/, $lookup{tags}) {
                $_ =~ s/^\s+//;
                $_ =~ s/\s+$//;
                if (exists $all_tags{$_}) {
                    $all_tags{$_} += 1;
                } else {
                    $all_tags{$_} = 1;
                }
            }
        }

        if ($continue_processing_index and $main_index_content =~ /{{$sectionname}}/) {
            if ($sectionname eq "essay") {
                $lookup{first} = $saw_first_essay_for_index ? '' : ' first';
                $saw_first_essay_for_index = 1;
            }

            $fill = fill($filepath, "./template/" . $sectionname . "_in_index", \%lookup);
            $main_index_content =~ s/{{$sectionname}}/$fill/;
        } else {
            $continue_processing_index = 0;
        }

        open FILE, ">", "$outdir/$sectionname/$lookup{filename}" or die $!;
        print FILE fill($filepath, "./template/" . $sectionname, \%lookup);
        close FILE
    }

    foreach (keys %article_index_lists) {
        open FILE, ">", "$outdir/$_/index.html" or die $!;
        print FILE fill("\$article_index_lists{$_}", "./template/" . $_ . "_index", {
            list => $article_index_lists{$_},
            pageurl => "$herokuserver/$_"
        });
        close FILE;
    }

    %tagcloud_class_lookup = get_tagcloud_class_lookup(\%all_tags);
    foreach (sort keys %all_tags) {
        $tagcloud .= "<span class=\"hide\">,</span> " if length($tagcloud) > 0;
        $tagcloud .= "<span class=\"" . $tagcloud_class_lookup{$all_tags{$_}} . "\">" . $_ . "</span>";
    }

    $main_index_content =~ s/{{tags}}/$tagcloud/;
    open FILE, ">", "$outdir/index.html" or die $!;
    print FILE $main_index_content;
    close FILE;

    `cp ./misc/robots.txt $outdir`;

    `mkdir $outdir/css`;
    `cp ./misc/all.css $outdir/css`;

    `mkdir $outdir/misc`;
    `cp ./misc/setup.html $outdir/misc`;
    `cp ./misc/thanks.html $outdir/misc`;
    `cp ./misc/todo.html $outdir/misc`;
}

sub read_as_string {
    my ($file, $flatten) = @_;
    my $data;
 
    $data = do { local $/ = undef; open my $fh, "<", $file or die $!; <$fh>; };
    $data =~ s/[\n\r]/ /g if $flatten;

    return $data;
}

sub fill {
    my $valuesfile = $_[0];
    my $templatefile = $_[1];
    my %lookup = %{$_[2]};
    my $template;
    my $data;
    my $key;

    $template = read_as_string($templatefile);

    while ($template =~ /{{(.+?)}}/) {
        $key = $1;
        die "'$key' value needed by $templatefile not in $valuesfile" if !exists $lookup{$key};
        $template =~ s/{{$key}}/$lookup{$key}/;
    }

    return $template;
}

sub get_tagcloud_class_lookup {
    my %tags = %{$_[0]};
    my %lookup = ();
    my $max = 1;
    my $min = 1;
    my @classes = ("max", "big", "above", "normal", "below", "small", "min");

    foreach (keys %tags) {
        $max = $tags{$_} if $tags{$_} > $max;
        $min = $tags{$_} if $tags{$_} < $min;
    }
print "max: $max\nmin: $min\n";

    $lookup{1} = "below";
    $lookup{2} = "normal";
    $lookup{4} = "above";

# TODO: how to return a function count -> class?
    return %lookup;
}
