# Run Program in inspect mode
cd "C:\Users\jbullock\OneDrive - Optical Zonu\Desktop\RPTConvert\CrystalReportWrapper\bin\Debug\net48"

.\CrystalReportWrapper.exe --report "C:\Users\jbullock\OneDrive - Optical Zonu\Desktop\RPTConvert\reports\SalesOrder - Copy.rpt" --inspect |
  Select-Object -Last 1 | ConvertFrom-Json | ConvertTo-Json -Depth 10 | Out-File inspect_salesorder.json

.\CrystalReportWrapper.exe --report "C:\Users\jbullock\OneDrive - Optical Zonu\Desktop\RPTConvert\reports\WorkOrderTraveler.rpt" --inspect |
  Select-Object -Last 1 | ConvertFrom-Json | ConvertTo-Json -Depth 10 | Out-File inspect_workorder.json


# Run Program with params.json

cd "C:\Users\jbullock\OneDrive - Optical Zonu\Desktop\RPTConvert\out"
# this command creates a .json file with Encoding utf 8
@'
{
  "Month_req": "August",
  "Month_Ordered": 8,
  "Year_Ordered": 2026
}
'@ | Set-Content -Path params.json -Encoding utf8

# Run Program with all four flags 

cd "C:\Users\jbullock\OneDrive - Optical Zonu\Desktop\RPTConvert\CrystalReportWrapper\bin\Debug\net48"

.\CrystalReportWrapper.exe `
  --report "C:\Users\jbullock\OneDrive - Optical Zonu\Documents\General.rpt\Backlog_RFoF_WO.rpt" `
  --output "C:\Users\jbullock\OneDrive - Optical Zonu\Desktop\RPTConvert\out\backlog.pdf" `
  --format PDF `
  --params "C:\Users\jbullock\OneDrive - Optical Zonu\Desktop\RPTConvert\out\params.json"
  