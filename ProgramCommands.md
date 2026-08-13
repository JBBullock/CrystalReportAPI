cd "C:\Users\jbullock\OneDrive - Optical Zonu\Desktop\RPTConvert\CrystalReportWrapper\bin\Debug\net48"

.\CrystalReportWrapper.exe --report "C:\Users\jbullock\OneDrive - Optical Zonu\Desktop\RPTConvert\reports\SalesOrder - Copy.rpt" --inspect |
  Select-Object -Last 1 | ConvertFrom-Json | ConvertTo-Json -Depth 10 | Out-File inspect_salesorder.json

.\CrystalReportWrapper.exe --report "C:\Users\jbullock\OneDrive - Optical Zonu\Desktop\RPTConvert\reports\WorkOrderTraveler.rpt" --inspect |
  Select-Object -Last 1 | ConvertFrom-Json | ConvertTo-Json -Depth 10 | Out-File inspect_workorder.json


  