
/ ** Run List

Steps:
(1) Run this SQL to build the key tables and features tables for analysis.  You must do this while connecting to a database
(2) Run Score_wranging.ipynb in Jupyter Notebook
(3) Run Data_wrangling_2.ipynb in Jupyter Notebook
(4) Run ne_Hot_Coding_Regions_and_Final_Wrangling.ipynb in Jupyter Notebook
(5) Run Finalize Data for Features Dataset.ipynb in Jupyter Notebook

Run List **/

/** Contents of this SQL file

studentAssessmentFULLSTG - Combines all the original data from the assessment and Student Asessment tables
studentVleFULLSTG - Combines all the original data from the VLE and the Student VLE activities
studentCourseRegistationFULLSTG - Combines all the original data from the Student, Course, and Registation tables
studentVleFeatures - Feature Engineering for all the VLE activities
studentAssessmentFeatures - Feature Engineering for all the assessment outcomes
studentCourseRegistrationFeatures - Feature Engineering for all the student, course and registration information
analysisFeatures - Combines all the feature tables into one table
studentVleFeatures2 - Second pass at creating VLE features for modeling; expanded the split of the activity over the course
analysisFeatures2 - Second pass at combining all the features into one table
hlf - Part 1 of building new features based on what a student has done at the half way mark of the course
hlf2 - Part 2 of building new features based on what a student has done at the half way mark of the course
studentAssessmentFULLHLF2STG - Creates staging table part 1 for half term calculations uses in the machine learning and feature analysis
studentAssessmentFULLHLF3STG - Creates staging table part 2 for half term calculations uses in the machine learning and feature analysis

**/

/*** Create the tables needed and then used Toad to import the CSV files
CREATE TABLE Public.”coursesSTG” (code_module varchar(45), code_presentation varchar(45), module_presentation_length int);
CREATE TABLE Public.”assessmentsSTG“ (code_module varchar(45), code_presentation varchar(45), id_assessment int, assessment_type varchar(45), date_set text, weight numeric);
CREATE TABLE Public.”studentAssessmentSTG” (id_assessment int, id_student int, date_submitted int, is_banked int, score text);
CREATE TABLE Public.”studentRegistrationSTG” (code_module varchar(45), code_presentation varchar(45), id_student int, date_registration text, date_unregistration text);
CREATE TABLE Public.”studentVleSTG” (code_module varchar(45), code_presentation varchar(45), id_student int, id_site int, date_set text, sum_click int);
CREATE TABLE Public.”vleSTG” (id_site int, code_module varchar(45), code_presentation varchar(45), activity_type text, week_from text, week_to text);
CREATE TABLE Public."studentInfoSTG" (code_module varchar(45), code_presentation varchar(45), id_student int, gender varchar(3), region varchar(45), highest_education varchar(45), imd_band varchar(16), age_band varchar(16), num_of_prev_attempts int, studied_credits int, disability varchar(3), final_result varchar(45));
***/

/** Creating the three combined data tables with the logical grouping of data for Assessments, VLE, and Student Registration and Course Information Combines**/

/** Creates a combined assessment table **/
CREATE TABLE public."studentAssessmentFULLSTG"
  AS (
	SELECT
		stdtasmt.*,
	    asmt.code_module,
	    asmt.code_presentation,
		asmt.assessment_type,
		asmt.final_sub_date,
		asmt.weight
	FROM
		public."assessmentsSTG" as asmt,
		public."studentAssessmentSTG" as stdtasmt
	WHERE
		asmt.id_assessment = stdtasmt.id_assessment
	ORDER BY stdtasmt.id_student, asmt.code_module, asmt.code_presentation
  );

/** Creates a combined VLE table **/
CREATE TABLE public."studentVleFULLSTG"
  AS (
	SELECT
	stdtvle.*,
	vle.activity_type,
	vle.week_from,
	vle.week_to
FROM
	public."vleSTG" as vle,
	public."studentVleSTG" as stdtvle
WHERE
	vle.id_site = stdtvle.id_site and vle.code_presentation = stdtvle.code_presentation and vle.code_module = stdtvle.code_module
ORDER BY stdtvle.id_student, stdtvle.code_module, stdtvle.code_presentation
  );
  
/** Creates a combined Student, Registration, and Courses table **/
CREATE TABLE public."studentCourseRegistationFULLSTG"
  AS (
	SELECT 
		stdt.*,
		stdtreg.data_registration,
		stdtreg.data_unregistration,
		crse.module_presentation_length
	FROM
		public."studentInfoSTG" as stdt,
		public."coursesSTG" as crse,
		public."studentRegistrationSTG" as stdtreg
	WHERE
		stdt.id_student = stdtreg.id_student and stdt.code_presentation = stdtreg.code_presentation and stdt.code_module = stdtreg.code_module
		AND crse.code_presentation = stdtreg.code_presentation and crse.code_module = stdtreg.code_module
	ORDER BY stdtreg.id_student, stdtreg.code_module, stdtreg.code_presentation
  );

/********* SQL DOCUMENTATION *****
Creates the table for the VLE Features table
	b4_sum_clicks - this is the number of clicks on the vle before the class started
	q1_sum_clicks - this is the number clicks during the first quarter of the class defines as the first 60 days
	q2_sum_clicks - this is the number clicks during the second quarter of the class defines as the first 60 - 120 days
	q3_sum_clicks - this is the number clicks during the third quarter of the class defines as the first 121 - 180 days
	q4_sum_clicks - this is the number clicks during the fourth quarter of the class defines as anything between day 181 and the end of class 
*********** SQL DOCUMENTATION ***** */
CREATE TABLE public."studentVleFeatures"
  AS (
select id_student, code_module, code_presentation,
sum(CASE
    		WHEN date_iact < 0 THEN sum_click
    		ELSE 0
		END) as b4_sum_clicks,	
sum(CASE
    		WHEN date_iact between 0 and 60 THEN sum_click
    		ELSE 0
		END) as q1_sum_clicks,
sum(CASE
    		WHEN date_iact between 61 and 120 THEN sum_click
    		ELSE 0
		END) as q2_sum_clicks,
sum(CASE
    		WHEN date_iact between 121 and 180 THEN sum_click
    		ELSE 0
		END) as q3_sum_clicks,
sum(CASE
    		WHEN date_iact > 180 THEN sum_click
    		ELSE 0
		END) as q4_sum_clicks	
from public."studentVleFULLSTG" as vle
group by id_student, code_module, code_presentation
order by id_student, code_module, code_presentation
);


/********* SQL DOCUMENTATION *****

Jinna to add comment

Creates the table for the studentAssessment Features table
std_half_score : The combinded score of TMA and CMA half way term
std_total_weight : The combinded weight of CMA and TMA
final_exam_score : final exam score

*********** SQL DOCUMENTATION ***** */

CREATE TABLE public."studentAssessmentFeatures"
AS
   (  SELECT id_student,
             code_module,
             code_presentation,
             sum (
                CASE
                   WHEN assessment_type IN ('CMA', 'TMA') and date_submitted <= hlf_module_lenght
                   THEN
                      (weight * score) / 100
                   ELSE
                      0
                END)
                AS std_half_weight_score,
             sum (
                CASE
                   WHEN assessment_type IN ('CMA', 'TMA') THEN (weight * score) / 100
                   ELSE 0
                END)
             AS std_total_score,
              sum (
                CASE
                   WHEN assessment_type IN ('CMA', 'TMA') THEN weight
                   ELSE 0
                END)
             AS std_total_weight
        FROM public."studentAssessmentFULLHLFSTG"
        where is_banked = 0
    GROUP BY id_student, code_module, code_presentation
    );

/*CREATE TABLE public."studentAssessmentFeaturesSTG"
AS
   (  SELECT id_student,
             code_module,
             code_presentation,
             sum (CASE WHEN assessment_type = 'Exam' THEN score ELSE 0 END)
                AS final_exam_score,
             sum (
                CASE
                   WHEN assessment_type IN ('CMA', 'TMA')
                   THEN
                      (weight * score) / 100
                   ELSE
                      0
                END)
                AS TMA_CMA_assmt_score,
             sum (
                CASE
                   WHEN assessment_type IN ('TMA') THEN (weight * score) / 100
                   ELSE 0
                END)
                AS TMA_assmt_score,
             sum (
                CASE
                   WHEN assessment_type IN ('CMA') THEN (weight * score) / 100
                   ELSE 0
                END)
                AS CMA_assmt_score,
             sum (
                CASE
                   WHEN assessment_type IN ('CMA', 'TMA') THEN weight
                   ELSE 0
                END)
                AS total_weight,
             count (CASE WHEN assessment_type = 'Exam' THEN 1 ELSE NULL END)
                AS final_exam,
             count (CASE WHEN is_banked = '1' THEN 1 ELSE NULL END)
                AS is_reenrolled
        FROM public."studentAssessmentFULLSTG"
    GROUP BY id_student, code_module, code_presentation);*/

/********* SQL DOCUMENTATION *****
Creates the table for the Student Course Registration Features table
	module_presentation_length - length of the class by days; integer
	Year - the class was taken (2013 or 2014)	
	Term - B means February and J means October
	start_month - translated from term; FEB means February and OCT mean October
	pass_fail_ind - pass fail indicator where NULL means withdrawn and PASS means either pass or distinction
	reg_period - registration period
						WEEKB4 - students registered within a week (0-7 days) before the class started
						MONTHB4 - students registered greater than a week and a month (30 days) before the class started 	
						QUARTERB4 - students registered greater than a month and a quarter (90 days) before the class started
						LONGB4 - students registered greater than 90 days before the class started
	module_domain - group of the type of class from Martin (dataset owner)
						Social Science courses are defined as AAA, BBB, and GGG
    					STEM courses are defined as CCC, DDD, EEE, FFF
	 
*********** SQL DOCUMENTATION ***** */

CREATE TABLE public."studentCourseRegistrationFeatures"
  AS (
	SELECT 
		crse.module_presentation_length,
		SUBSTRING(crse.code_presentation, 1, 4) as YEAR,
		SUBSTRING(crse.code_presentation, 5, 1) as TERM,
		CASE
    		WHEN SUBSTRING(crse.code_presentation, 5, 1) = 'B' THEN 'FEB'
    		WHEN SUBSTRING(crse.code_presentation, 5, 1) = 'J' THEN 'OCT'
    		ELSE NULL
		END AS start_month,
		stdt.*,
		CASE
    		WHEN UPPER(final_result) = 'FAIL' THEN 'FAIL'
    		WHEN UPPER(final_result) = 'PASS' THEN 'PASS'
    		WHEN UPPER(final_result) = 'DISTINCTION' THEN 'PASS'
    		ELSE NULL
		END AS pass_fail_ind,
	    stdtreg.date_registration, stdtreg.date_unregistration,
	    CASE
    		WHEN stdtreg.date_registration between -7 and 0 THEN 'WEEKB4'
    		WHEN stdtreg.date_registration between -30 and -8 THEN 'MONTHB4'
    		WHEN stdtreg.date_registration between -90 and -31 THEN 'QUARTERB4'
    		WHEN stdtreg.date_registration < -91 THEN 'LONGB4'
    		WHEN stdtreg.date_registration between 0 and 7 THEN 'WEEKAFTER'
    		WHEN stdtreg.date_registration between 8 and 30 THEN 'MONTHAFTER'
    		WHEN stdtreg.date_registration between 31 and 90 THEN 'QUARTERAFTER'
    		WHEN stdtreg.date_registration > 91 THEN 'LONGAFTER'
    		ELSE NULL
		END AS reg_period,
		CASE
    		WHEN stdt.code_module in ('AAA','BBB','GGG') THEN 'SocialScience'
    		WHEN stdt.code_module in ('CCC','DDD','EEE','FFF') THEN 'STEM'
    		ELSE NULL
		END AS module_domain
	FROM
		public."studentInfoSTG" as stdt,
		public."coursesSTG" as crse,
		public."studentRegistrationSTG" as stdtreg
	WHERE
		stdt.id_student = stdtreg.id_student and stdt.code_presentation = stdtreg.code_presentation and stdt.code_module = stdtreg.code_module
		AND crse.code_presentation = stdtreg.code_presentation and crse.code_module = stdtreg.code_module
	ORDER BY stdtreg.id_student, stdtreg.code_module, stdtreg.code_presentation
  );

/********* SQL DOCUMENTATION *****

	Combining all the feature datasets to create one table at the student, module, and presentation level

*********** SQL DOCUMENTATION ***** */

Create table public."analysisFeatures"
as 
(select stdtreg.id_student, stdtreg.code_module, stdtreg.code_presentation, stdtreg.module_domain, stdtreg.module_presentation_length,
        stdtreg.term, stdtreg.year, stdtreg.num_of_prev_attempts,
	    stdtreg.final_result, stdtreg.pass_fail_ind,
	   stdtreg.reg_period, stdtreg.date_registration, stdtreg.date_unregistration,
	   stdtreg.disability, stdtreg.gender, stdtreg.age_band, stdtreg.region, stdtreg.highest_education,
	     stdtreg.imd_band, stdtreg.studied_credits,asmtVle.b4_sum_clicks, asmtVle.q1_sum_clicks, asmtVle.q2_sum_clicks, asmtVle.q3_sum_clicks, asmtVle.q4_sum_clicks,
	   asmtVle.cma_assmt_score, asmtVle.tma_assmt_score, asmtVle.tma_cma_assmt_score, asmtVle.final_exam, asmtVle.total_weight,asmtVle.is_reenrolled,asmtVle.final_exam_score
from
	public."studentCourseRegistrationFeatures" as stdtreg LEFT join
	
	(select vle.b4_sum_clicks, vle.q1_sum_clicks, vle.q2_sum_clicks, vle.q3_sum_clicks, vle.q4_sum_clicks,
	   asmt.*
from
	public."studentAssessmentFeaturesSTG" asmt RIGHT JOIN
	public."studentVleFeatures" vle
on asmt.id_student = vle.id_student AND asmt.code_module = vle.code_module AND asmt.code_presentation = vle.code_presentation) as asmtVle
on stdtreg.id_student = asmtVle.id_student AND stdtreg.code_module = asmtVle.code_module AND stdtreg.code_presentation = asmtVle.code_presentation
);

/********* SQL DOCUMENTATION *****
Creates the table for the VLE Features table
	b4_sum_clicks - this is the number of clicks on the vle before the class started
	q1_sum_clicks - this is the number clicks during the first quarter of the class defines as the first 60 days
	q2_sum_clicks - this is the number clicks during the second quarter of the class defines as the first 60 - 120 days
	q3_sum_clicks - this is the number clicks during the third quarter of the class defines as the first 121 - 180 days
	q4_sum_clicks - this is the number clicks during the fourth quarter of the class defines as anything between day 181 and the end of class
	allclick - this is all the clicks by student for a class (ex. 'AAA') for a specific term (ex. 2014J)
	qtr_sum_clicks - this is the number clicks during the first quarter of the class defined by length of class divided by 4
	half_sum_click - this is the number clicks during the first quarter of the class defined by length of class divided by 2
	threeqtr_sum_clicks - this is the number clicks during the first quarter of the class defined by length of class times 3/4
	qtr_half_sum_clicks - this is the number clicks between during the first quarter of the class and the first half of the class
	half_threeqtr_sum_clicks - this is the number clicks between during the first half of the class and the 3/4 mark of the class
	thrd_sum_clicks - this is the number clicks during the first quarter of the class defined by length of class divided by 3
	twothrd_sum_clicks - this is the number clicks during the first quarter of the class defined by length of class time 2/3
	thrd_twothrd_sum_clicks is the number clicks between during the first third of the class and the second third of the class
	
	
*********** SQL DOCUMENTATION ******/

CREATE TABLE public."studentVleFeatures2"
  AS (
select vle.id_student, vle.code_module, vle.code_presentation,
sum(CASE
    		WHEN date_iact < 0 THEN sum_click
    		ELSE 0
		END) as b4_sum_clicks,	
sum(CASE
    		WHEN date_iact between 0 and 60 THEN sum_click
    		ELSE 0
		END) as q1_sum_clicks,
sum(CASE
    		WHEN date_iact between 61 and 120 THEN sum_click
    		ELSE 0
		END) as q2_sum_clicks,
sum(CASE
    		WHEN date_iact between 121 and 180 THEN sum_click
    		ELSE 0
		END) as q3_sum_clicks,
sum(CASE
    		WHEN date_iact > 180 THEN sum_click
    		ELSE 0
		END) as q4_sum_clicks,
sum(sum_click) as allclicks,
sum(CASE
    		WHEN date_iact between 0 and module_presentation_length/4 THEN sum_click
    		ELSE 0
		END) as qtr_sum_clicks,
sum(CASE
    		WHEN date_iact between 0 and module_presentation_length/2 THEN sum_click
    		ELSE 0
		END) as half_sum_clicks,
sum(CASE
    		WHEN date_iact between 0 and module_presentation_length*3/4 THEN sum_click
    		ELSE 0
		END) as threeqtr_sum_clicks,
sum(CASE
    		WHEN date_iact between module_presentation_length/4 and module_presentation_length/2 THEN sum_click
    		ELSE 0
		END) as qtr_half_sum_clicks,
sum(CASE
    		WHEN date_iact between module_presentation_length/2+1 and module_presentation_length*3/4 THEN sum_click
    		ELSE 0
		END) as half_threeqtr_sum_clicks,	
sum(CASE
    		WHEN date_iact between 0 and module_presentation_length/3 THEN sum_click
    		ELSE 0
		END) as thrd_sum_clicks,
sum(CASE
    		WHEN date_iact between 0 and module_presentation_length*2/3 THEN sum_click
    		ELSE 0
		END) as twothrd_sum_clicks,
sum(CASE
    		WHEN date_iact between module_presentation_length/3+1 and module_presentation_length/2 THEN sum_click
    		ELSE 0
		END) as thrd_twothrd_sum_clicks
from public."studentVleFULLSTG" as vle, public."coursesSTG" as crse
where vle.code_module = crse.code_module and vle.code_presentation = crse.code_presentation
group by vle.id_student, vle.code_module, vle.code_presentation
order by vle.id_student, vle.code_module, vle.code_presentation
);


/*********** SQL DOCUMENTATION *****
    Creates a new analysisFeatures tables with the new data from above
    Had to use LEFT OUTER JOIN to make sure all the students were represented snce since students didn't have any VLE activity
 ********* SQL DOCUMENTATION *******/
CREATE TABLE public."analysisFeatures2"
  AS (
select fte.*,
vle.qtr_sum_clicks,
vle.half_sum_clicks,
vle.threeqtr_sum_clicks,
vle.qtr_half_sum_clicks,
vle.half_threeqtr_sum_clicks,	
vle.thrd_sum_clicks,
vle.twothrd_sum_clicks,
vle.thrd_twothrd_sum_clicks
from public."analysisFeatures" fte LEFT JOIN public."studentVleFeatures2" vle
ON vle.id_student = fte.id_student and vle.code_module = fte.code_module and vle.code_presentation = fte.code_presentation
order by vle.id_student, vle.code_module, vle.code_presentation
);

/*********** SQL DOCUMENTATION *****
    Renames the old table with suffix of "Org" for original
    Renames new table to analysisFeatures to make sure python code isn't impacted
 ********* SQL DOCUMENTATION *******/
ALTER TABLE public."analysisFeatures"
RENAME TO "analysisFeaturesOrg";
	
ALTER TABLE public."analysisFeatures2"
RENAME TO "analysisFeatures";

/**  Logic and table create for the half course features **/

-- ** Builds a table to combine course and assessment information **
create table public."hlf" As 
(
SELECT asmt.*, crse.module_presentation_length, crse.module_presentation_length / 2 as hlf_module_length
FROM public."coursesSTG" crse, public."assessmentsSTG" asmt
WHERE crse.code_module = asmt.code_module AND crse.code_presentation = asmt.code_presentation
);

-- ** Creates features for assessment scores and logic for weights for half the term **
create table public."hlf2" As 
(
select code_module, code_presentation, hlf_module_length,
sum(
	case when final_sub_date <= hlf_module_length then weight
	else 0
	end ) as hlf_weight
from public."hlf"
group by code_module, code_presentation, hlf_module_length
);

-- ** Creates staging table part 1 for half term calculations uses in the machine learning and feature analysis **
create table public."studentAssessmentFULLHLF2STG" As 
(
select asmt.*, crse.hlf_module_length, hlf_weight
from public."studentAssessmentFULLSTG" asmt, public."hlf2" crse
where
crse.code_module = asmt.code_module AND crse.code_presentation = asmt.code_presentation
--crse.id_assessment = asmt.id_assessment
);

-- ** Creates staging table part 2 for half term calculations uses in the machine learning and feature analysis **
create table public."studentAssessmentFULLHLF3STG" As 
(
SELECT asmt.*, stdt.final_result, stdt.date_unregistration
FROM public."studentAssessmentFULLHLF2STG" asmt, public."studentCourseRegistrationFULLSTG" stdt
--from public."studentAssessmentFULLHLF2STG" asmt LEFT JOIN public."studentCourseRegistrationFULLSTG" stdt
WHERE stdt.code_module = asmt.code_module AND stdt.code_presentation = asmt.code_presentation AND stdt.id_student = asmt.id_student
--ON stdt.code_module = asmt.code_module AND stdt.code_presentation = asmt.code_presentation AND stdt.id_student = asmt.id_student
);

