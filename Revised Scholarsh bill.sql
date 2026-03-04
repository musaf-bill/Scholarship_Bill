/*
PURPOSE:		Combine three tables for comparison
					[msuf].[SCHLR_AWARD_WORK] that totals by FAS code
					[msuf].[SB_FUND_SUMMARY] imported from FE Fund Scholarship Fund Summary Report
					[msuf].[APPLICANT_AWARD] what has been awarded

*/

with BILLED AS (
	select --Total awards for each scholarship billed by MSU 
		w.FundCode as Fund,
		w.SeqNum as Seq,
		w.FundName,
		--w.Term,
		SUM(w.ScholAmtPd) AS TotScholAmtPd,
		sum(CASE WHEN SUBSTRING(w.Term,5,2) = '70' THen w.ScholAmtPd ELSE 0 END) as FallScholAmtPd,
		SUM(CASE WHEN SUBSTRING(w.Term,5,2) = '30' THen w.ScholAmtPd ELSE 0 END) as SprngScholAmtPd,
		sum(CASE WHEN SUBSTRING(w.Term,5,2) = '50' THen w.ScholAmtPd ELSE 0 END) as SmmrScholAmtPd,
		count(*) as Bill_Cnt,
		w.IndexNetCashBal,
		w.FAFundCode,
		w.FAIndexCode
	from MSUF.SCHLR_AWARD_WORK AS w

	group by 
		w.FundCode, 
		w.SeqNum, 
		w.FundName,
		w.IndexNetCashBal,
		w.FAFundCode,
		w.FADeptCode,
		w.FAIndexCode
		--w.Term
)
, CurrFundBal AS (
	SELECT
	fs.FUND_ID
	,fs.FUND_NAME
	,fs.AVAILABLE_CASH

	FROM msuf.SB_FUND_SUMMARY AS fs

)
, ApplicantAwards AS (
		SELECT
		AA.FAS_Code_Name AS FAS_CODE
		,SUBSTRING(AA.FAS_Code_Name,2,99) AS AbbrvFAS
		,SUM(AA.Total_Pd) AS Total_Pd
		,COUNT(GID) AS Pd_Count
		FROM [msuf].[SB_APPLICANT_AWARD] AS AA
		WHERE aa.Rec_type = 'AWARDS'
		GROUP BY aa.FAS_Code_Name,SUBSTRING(AA.FAS_Code_Name,2,99)
)
SELECT
  b.Fund AS [Fund (B)]
, b.FundName AS [FundName (B)]
, cbf.FUND_NAME AS [FundName (FE)]
, b.TotScholAmtPd
, b.FallScholAmtPd
, b.SprngScholAmtPd
, b.SmmrScholAmtPd
--, b.ScholAmtPd AS [ScholAmtPd (B)]
, b.Bill_Cnt
, b.FAFundCode
, b.FAIndexCode
, aa.Total_Pd AS [AA Total Pd]
, aa.Pd_Count AS [AA Pd Count]
, cbf.AVAILABLE_CASH AS [FE Available Cash]
,cbf.AVAILABLE_CASH - b.TotScholAmtPd AS BalanceCheck
,CASE WHEN aa.FAS_CODE IS NULL OR cbf.FUND_ID IS NULL THEN 'Yes' ELSE '' END AS FundCodeIssue 
,CASE WHEN cbf.AVAILABLE_CASH - b.TotScholAmtPd < 0 THEN 'Yes' ELSE '' END AS NSF
,CASE WHEN aa.Pd_Count - b.Bill_Cnt <> 0 THEN 'Yes' ELSE '' END AS AA_Count_Off

--,CASE WHEN b.IndexNetCashBal + b.ScholAmtPd <> 0 THEN CONVERT(NVARCHAR(10),b.IndexNetCashBal + b.ScholAmtPd) ELSE '' END  AS Index_Cash_Prob
--INTO #temp_tbl
FROM BILLED AS b
	LEFT JOIN ApplicantAwards AS aa
		ON aa.AbbrvFAS = b.FAFundCode
	LEFT JOIN CurrFundBal AS cbf
		ON cbf.FUND_ID = b.Fund