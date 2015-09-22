# ABSTRACT: clean up common abbreviations (most from Census data)
use strict;
use warnings;
use Moops;

package CalVAD::HPMS;

class CensusAbbrev using Moose : ro {
    use Carp;
    use Data::Dumper;
    use English qw(-no_match_vars);
    use version; our $VERSION = qv('0.1.0');

    use Text::CSV;
    use IO::File;
    use File::Find;

    has 'lookup_abbrev' => (
                           'is'    => 'ro',
                           'isa'   => 'HashRef',
                           'builder' => '_build_lookup'
                           );

    has 'reverse_lookup' => (
                           'is'    => 'rw',
                           'isa'   => 'HashRef',
                           );


    method _build_lookup {

      my $csv = Text::CSV->new ( { binary => 1 } )  # should set binary attribute.
                 or croak "Cannot use CSV: ".Text::CSV->error_diag ();

      # make filehandle
      my $fh = IO::File->new();


      my $files = [];

      sub loadfiles {
        my $files = shift;
        return sub{
          if (-f) {
            push @$files, grep { /\.csv/sxm } $File::Find::name;
          }
          return;
        };
      }

      find( loadfiles($files), '.' );

      if(! $fh->open($files->[0]) ){
        croak "cannot open $files->[0]";
      }
      my $firstline = $fh->getline();
      chomp $firstline;
      my @columns = split q/,/, $firstline;
      # tell the $csv parser how to parse the data
      $csv->column_names(@columns);
      my $lookup = {};
      my $revlookup = {};
      sub  add_entry{
        my ($lookup, $revlookup) = @_;
        return sub{
          my $data = shift;
          my $a = lc $data->{expanded_full_text};
          my $b = lc $data->{'display_name_abbreviation'};
          if( defined $lookup->{$a} ){
            croak "already have $a in lookup hash";
          }else{
            $lookup->{$a} =  $b;
          }
          if( defined $revlookup->{$b} ){
            $revlookup->{$b} .= q{|} . $a;
          }else{
            $revlookup->{$b} =  $a;
          }
        };
      }
      my $adder = add_entry($lookup,$revlookup);
      while ( my $data = $csv->getline_hr($fh)) {
          $adder->($data)
          # $adder->(lc $data->{'display_name_abbreviation'},lc $data->{expanded_full_text});
      }
      $fh->close();
      $self->reverse_lookup($revlookup);

      return $lookup;
    }




    method cleanup_noregex ( Str $fullname ){

        # special cases
        my $result;
        if($fullname =~ /coast hwy/i){
            $result ='Coast Hwy';
        }
        elsif($fullname =~ /SH\s*(\d+)/i){
            $result ="State Hwy $1";
            $fullname =~ s/SH\s*\d+//i;
        }

        return ($fullname,$result);
    }


    method part_cleanup ( Str $part ){

        # get rid of parenthetical remarks
        if($part =~ /\(.*\)/){
            $part =~ s/\(.*\)//;
        }
        # get rid of stray parentheses
        $part =~ s/\(//;
        $part =~ s/\)//;
        # get rid of distance notations
        if($part =~ /\d*\.\d+\s*(m|ft)/i){
            $part =~ s/\d*\.\d+\s*(m|ft)//i;
        }
        $part =~ s/^(N|S|E|W)\///i;
        # get rid of stray decimals (like st. or ave. idiocy)
        $part =~ s/\.\b//;

        # get rid of stray plus signs.  I mean really, what is the point of E BAYSHORE RD + ??
        if($part =~ /\+/){
            $part =~ s/\+//;
        }

        return $part;
    }

    method polish_part ( Str $part, Bool $regex = 0){

        if(! length $part){
            return ;
        }

        if($part =~ /interstate/i || $part =~ /^I-/){
            # break out the number of the interstate
            my $number ;
            if($part =~ /(interstate\s*|I-\s*)(\d+)/){
                $number = $2;
            }
            my $string = "I-$number";
            return $string;
        } else {

            my $abbr = $self->lookup_abbrev->{lc $part} ;
            if(!defined $abbr ){
                return $part;
            }else{
                if($regex){
                    # combine the abbrev and the original term in a regex type entry
                    my $string = q/(/ .
                        join ( q/|/ , $part, $abbr )
                        . q/)/ ;
                    return $string;
                }else{
                    # replace the original with the official  abbreviation
                    return $abbr;
                }
            }
        }
        return;
    }

    sub fix_tooth{
        my $result = shift;
        if($result =~ /2th/i && $result !~ /12th/i){
            $result =~ s/2th/2nd/i;
        }
        if($result =~ /1th/i && $result !~ /11th/i) {
            $result =~ s/[^1]*1th/1st/i;
        }
        if($result =~ /3th/i && $result !~ /13th/i ){
            $result =~ s/[^1]*3th/3rd/i;
        }
        return $result;
    }

    # trigram function does not want regex searches
    method replace_census_abbrev_trigram( Str $fullname, Bool $fromto = 0 ){
        my $result;
        if ( $fullname =~ /^CL|CL$|CITY LIMIT/ ){
            return 'CL';
        }
        ($fullname,$result) = $self->cleanup_noregex($fullname);

        my @parts = split q{ }, $fullname ;
        my @rebuild = ();

        # due to bad planning, the string is in two inch lengths

        # only replace the first and last elements of the parts with abbrev
        my $first_part = shift @parts;
        my $last_part = pop @parts;

        if(scalar @parts){
            if($first_part){
                my $part = $self->part_cleanup($first_part);
                push @rebuild,  $self->polish_part($part);
            }
            push @rebuild, map { $self->part_cleanup($_) } @parts;
            if($last_part){
                my $part = $self->part_cleanup($last_part);
                push @rebuild, $self->polish_part($part);
            }
        }else{
            #do nothing
            for ($first_part,$last_part){
                if($_){
                    push @rebuild,  $self->part_cleanup($_);
                }
            }
        }
        my $rebuild =  join q{ },@rebuild;

        if($fromto){

            # nothing yet

        }
        # make it start at the beginning

        if(! $result){
            $result = $rebuild;
        }

        # fix 2th to 2nd and 1th to 1st and 3th to 3rd
        $result = fix_tooth( $result );

        return $result;
    }

}


1;
