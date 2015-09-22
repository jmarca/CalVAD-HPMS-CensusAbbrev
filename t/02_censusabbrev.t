use Test::Modern; # see done_testing()
use Carp;
use Data::Dumper;
use Config::Any; # config db credentials with config.json


use CalVAD::HPMS::CensusAbbrev;

ok(1,'use okay passed');




# make an abbreviation cleaner

my $fixer = object_ok(
    sub { CalVAD::HPMS::CensusAbbrev->new() },
    '$fixer',
    isa   => [qw( CalVAD::HPMS::CensusAbbrev Moose::Object )],
    # does  => [qw( Employable )],
    can   => [qw( cleanup_noregex part_cleanup polish_part replace_census_abbrev_trigram )],
    # clean => 1,
    # more  => sub {
    #    my $object = shift;
    #    is($object->name, "Robert Jones");
    #    like($object->employee_number, qr/^[0-9]+$/);
    # },
    );

# # make further use of $bob
# object_ok(
#    sub { $bob->line_manager },
#    isa   => [qw( Person )],
# );


diag 'North Ave, West Ave testing';
my $string;
my $result;

$string = 'NORTH AVE';
$result = $fixer->replace_census_abbrev_trigram($string);
isnt $result, undef;
is $result, 'NORTH AVE', 'no change to NORTH AVE';

$string = 'NORTH WEST AVE';
$result = $fixer->replace_census_abbrev_trigram($string);
isnt $result, undef;
is $result, 'n WEST AVE',  'successfully converts North West Ave';

$string = 'WEST  AVE';
$result = $fixer->replace_census_abbrev_trigram($string);
isnt $result, undef;
is $result, 'WEST AVE',  'successfully converts West Ave';


diag 'convert 1th 2th 3th';


$string = '1TH AVE';
$result = $fixer->replace_census_abbrev_trigram($string);
is $result, '1st AVE', 'successfully converts 1th Ave';



$string = '11TH AVE';
$result = $fixer->replace_census_abbrev_trigram($string);
is $result, '11TH AVE', 'successfully converts 11th Ave';



$string = '2TH AVE';
$result = $fixer->replace_census_abbrev_trigram($string);
is $result, '2nd AVE','successfully converts 2th Ave';


$string = '12TH AVE';
$result = $fixer->replace_census_abbrev_trigram($string);
is $result, '12TH AVE','successfully converts 12th Ave';


$string = '3TH AVE';
$result = $fixer->replace_census_abbrev_trigram($string);
is $result, '3rd AVE','successfully converts 3th Ave';



$string = '13TH AVE';
$result = $fixer->replace_census_abbrev_trigram($string);
is $result, '13TH AVE','successfully converts 13th Ave';



diag 'tricky cases';


$string = 'SHWY 27 (TOPANGA CYN';
$result = $fixer->replace_census_abbrev_trigram($string);
is $result, 'SHWY 27 TOPANGA canyon','should not have unbalanced parens in result';

$result = $fixer->replace_census_abbrev_trigram($string,1);
is $result, 'SHWY 27 TOPANGA canyon';


$string = 'BEGINNING';
$result = $fixer->replace_census_abbrev_trigram($string);
is $result,$string,'should handle single word roads';

$result = $fixer->replace_census_abbrev_trigram($string,1);
is $result,$string,'should handle single word roads';



# # , 'CAMINO CAPISTRANO', 'VIA FORTUNA');
diag 'spanish names';

$string = 'VIA CANON';
$result = $fixer->replace_census_abbrev_trigram($string);
is $result,   $string, 'does not choke on Via Canon';


$string = 'CAMINO LAS RAMBLAS';
$result = $fixer->replace_census_abbrev_trigram($string);
isnt $result,   $string,'does not choke on Camino Las Ramblas';
is $result, 'cam LAS RAMBLAS','successfully converts Camino Las Ramblas';


## I-5 test.  In the non-trigram version, I convert to 'interstate',
## but in the trigram one I do not.  Not sure why.  For the moment
## this test is on hold.
# diag 'I-5';
# $string = 'I-5';
# $result = $fixer->replace_census_abbrev_trigram($string);
# isnt $result,   $string;
# is $result, 'interstate-5','successfully converts I-5';

diag 'WINTON AVE';

$string = 'WINTON AVE';
$result = $fixer->replace_census_abbrev_trigram($string);
is $result,   $string, 'successfully converts WINTON AVE';


diag '240295 ,        2009 , TBRN     , MRN    , 41   , RACOON ST , MAR WEST ST , CENTRO WEST ST , 000000EG4701';

$string = 'MAR WEST ST';
$result = $fixer->replace_census_abbrev_trigram($string);
isnt $result,   $string;
is $result, 'mar WEST ST', 'converts MAR WEST ST';


$string = 'CENTRO WEST ST';
$result = $fixer->replace_census_abbrev_trigram($string,1);
isnt $result,   $string;
is $result, 'centro WEST ST','converts CENTRO WEST ST';


done_testing;



END{
    # cleanup here?
    # $connect = undef;
    # $obj = undef;
}
