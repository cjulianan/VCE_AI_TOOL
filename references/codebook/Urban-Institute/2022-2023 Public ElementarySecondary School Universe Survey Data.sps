* Encoding: UTF-8.
***********************************************************************************************************.
*     Program: Code_to_create_SCH_Directory_File_2022-23.sps                                              *.
*        Note: 1) This program reads in the nonfiscal CCD School Directory data file and creates          *.
*                 an SPSS system data file.                                                               *.
*              2) Edit/change code in the 5 places indicated below.  Leave all remaining code unchanged.  *.
*              3) When naming your SPSS data files, do not include spaces in the data file name           *.
*   Last updated: December 5, 2023 		                                                          *.
***********************************************************************************************************.



DEFINE ![name your data file] ()                  /* replace [name your data file] with your own data file name  */
'[insert path]\[insert file name]'.                 /* replace [insert path] and [insert file name] to read in the data file */
!ENDDEFINE.


DEFINE !varlist ()
SCHOOL_YEAR A9
FIPST A2
STATENAME A44
ST A2
SCH_NAME A60
LEA_NAME A60
STATE_AGENCY_NO A3
UNION A3
ST_LEAID A35
LEAID A7
ST_SCHID A45
NCESSCH A12
SCHID A7
MSTREET1 A60
MSTREET2 A60
MSTREET3 A60
MCITY A30
MSTATE A2
MZIP A5
MZIP4 A4
LSTREET1 A60
LSTREET2 A60
LSTREET3 A60
LCITY A30
LSTATE A2
LZIP A5
LZIP4 A4
PHONE A13
WEBSITE A256
SY_STATUS A1
SY_STATUS_TEXT A30
UPDATED_STATUS A1
UPDATED_STATUS_TEXT A30
EFFECTIVE_DATE A20
SCH_TYPE_TEXT A28
SCH_TYPE A1
RECON_STATUS A3
OUT_OF_STATE_FLAG A3
CHARTER_TEXT A30
CHARTAUTH1 A20
CHARTAUTHN1 A60
CHARTAUTH2 A20
CHARTAUTHN2 A60
NOGRADES A12
G_PK_OFFERED A12
G_KG_OFFERED A12
G_1_OFFERED A12
G_2_OFFERED A12
G_3_OFFERED A12
G_4_OFFERED A12
G_5_OFFERED A12
G_6_OFFERED A12
G_7_OFFERED A12
G_8_OFFERED A12
G_9_OFFERED A12
G_10_OFFERED A12
G_11_OFFERED A12
G_12_OFFERED A12
G_13_OFFERED A12
G_UG_OFFERED A12
G_AE_OFFERED A12
GSLO A2
GSHI A2
LEVEL A16
IGOFFERED A14
.
!ENDDEFINE.


*** Read in the comma-delimited data file ***.

GET DATA   /TYPE = TXT
 /FILE = '[insert path]\[insert file name]'   			/* replace [insert path] and [insert file name] to read in the data file */
 /DELIMITERS = ","
 /QUALIFIER='"'
 /ARRANGEMENT = DELIMITED
 /FIRSTCASE = 2
 /IMPORTCASE = ALL
 /ENCODING='LOCALE'
 /VARIABLES = !varlist.

FILE LABEL '[name your data file]'.        /* replace [name your data file] with your own data file name  */                   
                                                                                                         


ALTER TYPE  SCHOOL_YEAR (A9).
ALTER TYPE  FIPST (A2).
ALTER TYPE  STATENAME (A44).
ALTER TYPE  ST (A2).
ALTER TYPE  SCH_NAME (A60).
ALTER TYPE  LEA_NAME (A60).
ALTER TYPE  STATE_AGENCY_NO (A3).
ALTER TYPE  UNION (A3).
ALTER TYPE  ST_LEAID (A35).
ALTER TYPE  LEAID (A7).
ALTER TYPE  ST_SCHID (A45).
ALTER TYPE  NCESSCH (A12).
ALTER TYPE  SCHID (A7).
ALTER TYPE  MSTREET1 (A60).
ALTER TYPE  MSTREET2 (A60).
ALTER TYPE  MSTREET3 (A60).
ALTER TYPE  MCITY (A30).
ALTER TYPE  MSTATE (A2).
ALTER TYPE  MZIP (A5).
ALTER TYPE  MZIP4 (A4).
ALTER TYPE  LSTREET1 (A60).
ALTER TYPE  LSTREET2 (A60).
ALTER TYPE  LSTREET3 (A60).
ALTER TYPE  LCITY (A30).
ALTER TYPE  LSTATE (A2).
ALTER TYPE  LZIP (A5).
ALTER TYPE  LZIP4 (A4).
ALTER TYPE  PHONE (A13).
ALTER TYPE  WEBSITE (A80).
ALTER TYPE  SY_STATUS (A1).
ALTER TYPE  SY_STATUS_TEXT (A30).
ALTER TYPE  UPDATED_STATUS (A1).
ALTER TYPE  UPDATED_STATUS_TEXT (A30).
ALTER TYPE  EFFECTIVE_DATE (A20).
ALTER TYPE  SCH_TYPE_TEXT (A28).
ALTER TYPE  SCH_TYPE (A1).
ALTER TYPE  RECON_STATUS (A3).
ALTER TYPE  OUT_OF_STATE_FLAG (A3).
ALTER TYPE  CHARTER_TEXT (A30).
ALTER TYPE  CHARTAUTH1 (A20).
ALTER TYPE  CHARTAUTHN1 (A60).
ALTER TYPE  CHARTAUTH2 (A20).
ALTER TYPE  CHARTAUTHN2 (A60).
ALTER TYPE  NOGRADES (A12).
ALTER TYPE  G_PK_OFFERED (A12).
ALTER TYPE  G_KG_OFFERED (A12).
ALTER TYPE  G_1_OFFERED (A12).
ALTER TYPE  G_2_OFFERED (A12).
ALTER TYPE  G_3_OFFERED (A12).
ALTER TYPE  G_4_OFFERED (A12).
ALTER TYPE  G_5_OFFERED (A12).
ALTER TYPE  G_6_OFFERED (A12).
ALTER TYPE  G_7_OFFERED (A12).
ALTER TYPE  G_8_OFFERED (A12).
ALTER TYPE  G_9_OFFERED (A12).
ALTER TYPE  G_10_OFFERED (A12).
ALTER TYPE  G_11_OFFERED (A12).
ALTER TYPE  G_12_OFFERED (A12).
ALTER TYPE  G_13_OFFERED (A12).
ALTER TYPE  G_UG_OFFERED (A12).
ALTER TYPE  G_AE_OFFERED (A12).
ALTER TYPE  GSLO (A2).
ALTER TYPE  GSHI (A2).
ALTER TYPE  LEVEL (A16).
ALTER TYPE  IGOFFERED (A14).
EXECUTE.


VARIABLE LABELS
SCHOOL_YEAR	'Year corresponding to survey record'
FIPST	'American National Standards Institute (ANSI) state code'
STATENAME	'State name'
ST	'Postal state abbreviation code'
SCH_NAME	'School name'
LEA_NAME	'Education Agency Name'
STATE_AGENCY_NO	'Identifier of the reporting state agency'
UNION	'Supervisory Union (SU) Identification Number. For SU administrative centers and component agencies, this is assigned by the state. If the agency is a county superintendent, this is the ANSI county number. If not reported, the field is null'
ST_LEAID	'State Local Education Number. State’s own ID for the education agency.'
LEAID	'NCES Agency Identification Number'
ST_SCHID	'State school identifier'
NCESSCH	'School Identifier (NCES)'
SCHID	'Unique school ID'
MSTREET1	'Mailing address; street 1'
MSTREET2	'Mailing address; street 2'
MSTREET3	'Mailing address; street 3'
MCITY	'Mailing city'
MSTATE	'Mailing state. Two-letter U.S. Postal Service abbreviation of the state where the mailing address is located'
MZIP	'Mailing 5 digit ZIP code'
MZIP4	'Mailing Secondary ZIP code'
LSTREET1	'Location address; street 1'
LSTREET2	'Location address; street 2'
LSTREET3	'Location address; street 3'
LCITY	'Location city'
LSTATE	'Location state. Two-letter U.S. Postal Service abbreviation'
LZIP	'Location 5 digit ZIP code'
LZIP4	'Location Secondary ZIP code'
PHONE	'Telephone number'
WEBSITE	'The Uniform Resource Locator (URL) for the unique address of a Web Page of an education entity.'
SY_STATUS	'Start of year Status (code)'
SY_STATUS_TEXT	 'Start of year Status (description)'
UPDATED_STATUS	'Updated status (code)'
UPDATED_STATUS_TEXT	'Updated status (description)'
EFFECTIVE_DATE	 'Effective date of updated status'
SCH_TYPE_TEXT	'School type (description)'
SCH_TYPE	'School type (code)'
RECON_STATUS	'Reconstituted flag'
OUT_OF_STATE_FLAG	'Mailing or Location address is in another state'
CHARTER_TEXT	'Whether a Charter school'
CHARTAUTH1	'Charter authorizer state ID (1). The identifier assigned to the primary public charter school authorizing agency by the SEA'
CHARTAUTHN1	'Charter authorizer name (1).'
CHARTAUTH2	'Charter authorizer state ID (2). The identifier assigned to the primary public charter school authorizing agency by the SEA.'
CHARTAUTHN2	'Charter authorizer name (2).'
NOGRADES	'No grades offered'
G_PK_OFFERED	'PK Grade Offered'
G_KG_OFFERED	'KG Grade Offered'
G_1_OFFERED	'Grade 01 Offered'
G_2_OFFERED	'Grade 02 Offered'
G_3_OFFERED	'Grade 03 Offered'
G_4_OFFERED	'Grade 04 Offered'
G_5_OFFERED	'Grade 05 Offered'
G_6_OFFERED	'Grade 06 Offered'
G_7_OFFERED	'Grade 07 Offered'
G_8_OFFERED	'Grade 08 Offered'
G_9_OFFERED	'Grade 09 Offered'
G_10_OFFERED	'Grade 10 Offered'
G_11_OFFERED	'Grade 11 Offered'
G_12_OFFERED	'Grade 12 Offered'
G_13_OFFERED	'Grade 13 Offered'
G_UG_OFFERED	'Ungraded offered'
G_AE_OFFERED	'Adult education offered'
GSLO	'Grades Offered - Lowest'
GSHI	'Grades Offered - Highest'
LEVEL	'LEA or school level'
IGOFFERED	'Whether any grades-offered field was adjusted'
.

VALUE LABELS
   /SY_STATUS
'1'  '1- Open'
'2'  '2- Closed'
'3'  '3- New'
'4'  '4- Added'
'5'  'Changed Boundary/Agency'
'6'  'Inactive'
'7'  'Future'
'8'  'Reopened'
 /UPDATED_STATUS
'1'  '1- Open'
'2'  '2- Closed'
'3'  '3- New'
'4'  '4- Added'
'5'  '5- Changed Boundary/Agency'
'6'  '6- Inactive'
'7'  '7- Future'
'8'  '8- Reopened'
  /SCH_TYPE
'1'  '1- Regular School'
'2'  '2- Special Education School'
'3'  '3- Career or Technical School'
'4'  '4- Alternative Education School'
 /GSLO
'01'  '01 - Grade 1'
'02'  '02 - Grade 2'
'03'  '03 - Grade 3'
'04'  '04 - Grade 4'
'05'  '05 - Grade 5'
'06'  '06 - Grade 6'
'07'  '07 - Grade 7'
'08'  '08 - Grade 8'
'09'  '09 - Grade 9'
'10'  '10 - Grade 10'
'11'  '11 - Grade 11'
'12'  '12 - Grade 12'
'AE'  'AE - Adult Education'
'KG'  'KG - Kindergarten'
'N'   'N - Grade not applicable'
'PK'  'PK - Prekindergarten'
'UG'  'UG - Ungraded'
'M'   'M - Grade missing'
 /GSHI
'01'  '01 - Grade 1'
'02'  '02 - Grade 2'
'03'  '03 - Grade 3'
'04'  '04 - Grade 4'
'05'  '05 - Grade 5'
'06'  '06 - Grade 6'
'07'  '07 - Grade 7'
'08'  '08 - Grade 8'
'09'  '09 - Grade 9'
'10'  '10 - Grade 10'
'11'  '11 - Grade 11'
'12'  '12 - Grade 12'
'13'  '13 - Grade 13'
'AE'  'AE - Adult Education'
'KG'  'KG - Kindergarten'
'N'   'N - Grade not applicable'
'PK'  'PK - Prekindergarten'
'UG'  'UG - Ungraded'
'M'   'M - Grade missing'
 .

SAVE OUTFILE '[insert path]\[insert file name]' /COMPRESSED.   	/* replace [insert path] and [insert file name] to save your own data file */
                                                                        	
EXECUTE.

CACHE.
EXECUTE.





