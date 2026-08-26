import re

path = "Program.cs"
text = open(path, encoding="utf-8").read()

marker = "// WorkOrderTraveler_TTX is INTENTIONALLY NOT in this catalog"
start = text.index(marker)
end = text.index("};", start) + len("};")
old_block = text[start:end]
assert marker in old_block

new_block = r'''// WorkOrderTraveler_TTX - confirmed against woheader (WO
            // header: dates/quantities) + routers (the part's standard
            // routing steps - one row per operation, keyed by PartNumber,
            // NOT WONumber; a router entry has no wonumber column at all,
            // it's the routing template for that part, not a per-WO
            // schedule) + partmaster/workcenters/operationcodes for the
            // three *_DescText/Name lookups. This matches the field list
            // exactly: WONumber/PartNumber/StartDate/etc. come from
            // woheader, while OperationCode/SequenceID/WorkCenterID/
            // IsAlternate/QueueTime/SetUpTime/RunTime come from routers.
            // "Notes"/"Isnull_Notes" assumed to be the WO header's own
            // notes field (routers has its own "notes" column too, but
            // WorkOrderTraveler_TTX only has ONE Notes field, and the
            // report's header box - Work Order #/Job Number/Part Number -
            // is where a single free-text Notes field would naturally
            // live) - verify against the actual printed report once real
            // data is flowing, and swap to r.notes if it looks wrong.
            ["WorkOrderTraveler_TTX"] = @"
                SELECT
                    wo.wonumber AS ""WONumber"",
                    wo.partnumber AS ""PartNumber"",
                    r.operationcode AS ""OperationCode"",
                    r.sequenceid AS ""SequenceID"",
                    wo.jobnumber AS ""JobNumber"",
                    wo.startdate AS ""StartDate"",
                    wo.requireddate AS ""RequiredDate"",
                    wo.quantitytostart AS ""QuantityToStart"",
                    wo.quantityrequired AS ""QuantityRequired"",
                    wo.quantityreleased AS ""QuantityReleased"",
                    wo.workorderuom AS ""WorkOrderUOM"",
                    wo.quantitycompleted AS ""QuantityCompleted"",
                    r.workcenterid AS ""WorkCenterID"",
                    r.isalternate AS ""IsAlternate"",
                    r.queuetime AS ""QueueTime"",
                    r.setuptime AS ""SetUpTime"",
                    r.runtime AS ""RunTime"",
                    wo.notes AS ""Notes"",
                    (CASE WHEN wo.notes IS NULL THEN 1 ELSE 0 END) AS ""Isnull_Notes"",
                    pm.stockuom AS ""StockUOM"",
                    pm.densitycode AS ""DensityCode"",
                    pm.desctext AS ""PartMaster_DescText"",
                    wc.workcentername AS ""WorkCenterName"",
                    oc.desctext AS ""OperationCodes_DescText""
                FROM woheader wo
                LEFT JOIN routers r ON r.partnumber = wo.partnumber
                LEFT JOIN partmaster pm ON pm.partnumber = wo.partnumber
                LEFT JOIN workcenters wc ON wc.workcenterid = r.workcenterid
                LEFT JOIN operationcodes oc ON oc.operationcode = r.operationcode;",

            // PurchaseOrder_TTX - poheader+podetail (one row per PO line),
            // joined out to partmaster, suppliers/supplieraddress (the
            // "SupplierAddress_*" fields), companyaddress (BillToAddress_*/
            // ShipToAddress_* - poheader.billtoaddress/shiptoaddress point
            // at the BUYER's own address book, not the supplier's - same
            // inversion of SOHeader's convention there, since here the
            // company IS the buyer), and the same tax/terms/currency code
            // tables used elsewhere. Address FK columns (poheader.
            // billtoaddress/shiptoaddress/supplieraddress) are integer;
            // addressid columns are character varying - cast the integer
            // side to text to join. Money fields (ExtendedAmount/
            // BaseTaxAmount/.../LineTotal) are INFERRED the same way
            // SalesOrder_TTX's were: computed here from quantity/price/
            // tax-rate, not stored columns - not guessed, but not
            // confirmed against a real printed PO either.
            ["PurchaseOrder_TTX"] = @"
                SELECT
                    pd.ponumber AS ""PONumber"",
                    po.requisitionnumber AS ""RequisitionNumber"",
                    svc.desctext AS ""ShipViaDescription"",
                    po.buyercode AS ""BuyerCode"",
                    po.departmentcode AS ""DepartmentCode"",
                    po.orderdate AS ""OrderDate"",
                    po.currencycode AS ""CurrencyCode"",
                    po.exchangerate AS ""ExchangeRate"",
                    po.requireddate AS ""POHeader_RequiredDate"",
                    fc.desctext AS ""FOBDescription"",
                    pd.poline AS ""POLine"",
                    pd.partnumber AS ""PartNumber"",
                    pd.pounitprice AS ""POUnitPrice"",
                    pd.quantityordered AS ""QuantityOrdered"",
                    pd.purchaseuom AS ""PurchaseUOM"",
                    pd.taxableflag AS ""TaxableFlag"",
                    pd.basetaxcode AS ""BaseTaxCode"",
                    pd.taxflag2 AS ""TaxFlag2"",
                    pd.taxcode2 AS ""TaxCode2"",
                    pd.taxflag3 AS ""TaxFlag3"",
                    pd.taxcode3 AS ""TaxCode3"",
                    pd.revision AS ""Revision"",
                    pd.kitpartflag AS ""KitPartFlag"",
                    pd.partxreference AS ""PartXReference"",
                    pd.requireddate AS ""PODetail_RequiredDate"",
                    pm.desctext AS ""PartMaster_DescText"",
                    pm.stockuom AS ""StockUOM"",
                    tx1.taxrate AS ""BaseTaxRate"",
                    tx2.taxrate AS ""TaxRate2"",
                    tx3.taxrate AS ""TaxRate3"",
                    s.suppliername AS ""SupplierName"",
                    s.companyaccount AS ""CompanyAccount"",
                    supaddr.addressline1 AS ""SupplierAddress_AddressLine1"",
                    supaddr.addressline2 AS ""SupplierAddress_AddressLine2"",
                    supaddr.addressline3 AS ""SupplierAddress_AddressLine3"",
                    supaddr.addressline4 AS ""SupplierAddress_AddressLine4"",
                    supaddr.city AS ""SupplierAddress_City"",
                    supaddr.state AS ""SupplierAddress_State"",
                    supaddr.zipcode AS ""SupplierAddress_ZIPCode"",
                    supaddr.country AS ""SupplierAddress_Country"",
                    supaddr.postal AS ""SupplierAddress_Postal"",
                    tc.desctext AS ""TermsCodes_DescText"",
                    cc.currencysymbol AS ""CurrencySymbol"",
                    po.notes AS ""Notes"",
                    pd.linenotes AS ""LineNotes"",
                    (CASE WHEN po.notes IS NULL THEN 1 ELSE 0 END) AS ""POHeader_IsnullNotes"",
                    (CASE WHEN pd.linenotes IS NULL THEN 1 ELSE 0 END) AS ""PODetail_IsnullLineNotes"",
                    billaddr.addressline1 AS ""BillToAddress_AddressLine1"",
                    billaddr.addressline2 AS ""BillToAddress_AddressLine2"",
                    billaddr.addressline3 AS ""BillToAddress_AddressLine3"",
                    billaddr.addressline4 AS ""BillToAddress_AddressLine4"",
                    billaddr.city AS ""BillToAddress_City"",
                    billaddr.state AS ""BillToAddress_State"",
                    billaddr.zipcode AS ""BillToAddress_ZipCode"",
                    billaddr.country AS ""BillToAddress_Country"",
                    billaddr.postal AS ""BillToAddress_Postal"",
                    shipaddr.addressline1 AS ""ShipToAddress_AddressLine1"",
                    shipaddr.addressline2 AS ""ShipToAddress_AddressLine2"",
                    shipaddr.addressline3 AS ""ShipToAddress_AddressLine3"",
                    shipaddr.addressline4 AS ""ShipToAddress_AddressLine4"",
                    shipaddr.city AS ""ShipToAddress_City"",
                    shipaddr.state AS ""ShipToAddress_State"",
                    shipaddr.zipcode AS ""ShipToAddress_ZipCode"",
                    shipaddr.country AS ""ShipToAddress_Country"",
                    shipaddr.postal AS ""ShipToAddress_Postal"",
                    (pd.quantityordered * pd.pounitprice) AS ""ExtendedAmount"", -- INFERRED
                    (CASE WHEN pd.taxableflag THEN (pd.quantityordered * pd.pounitprice) * COALESCE(tx1.taxrate, 0) ELSE 0 END) AS ""BaseTaxAmount"", -- INFERRED
                    (pd.quantityordered * pd.pounitprice) AS ""LineSubtotal"", -- INFERRED: assumed equal to ExtendedAmount
                    (CASE WHEN pd.taxflag2 THEN (pd.quantityordered * pd.pounitprice) * COALESCE(tx2.taxrate, 0) ELSE 0 END) AS ""Tax2Amount"", -- INFERRED
                    (CASE WHEN pd.taxflag3 THEN (pd.quantityordered * pd.pounitprice) * COALESCE(tx3.taxrate, 0) ELSE 0 END) AS ""Tax3Amount"", -- INFERRED
                    (
                        (pd.quantityordered * pd.pounitprice)
                        + (CASE WHEN pd.taxableflag THEN (pd.quantityordered * pd.pounitprice) * COALESCE(tx1.taxrate, 0) ELSE 0 END)
                        + (CASE WHEN pd.taxflag2 THEN (pd.quantityordered * pd.pounitprice) * COALESCE(tx2.taxrate, 0) ELSE 0 END)
                        + (CASE WHEN pd.taxflag3 THEN (pd.quantityordered * pd.pounitprice) * COALESCE(tx3.taxrate, 0) ELSE 0 END)
                    ) AS ""LineTotal"" -- INFERRED
                FROM podetail pd
                JOIN poheader po ON po.ponumber = pd.ponumber
                LEFT JOIN partmaster pm ON pm.partnumber = pd.partnumber
                LEFT JOIN suppliers s ON s.supplierid = po.supplierid
                LEFT JOIN supplieraddress supaddr ON supaddr.supplierid = po.supplierid AND supaddr.addressid = po.supplieraddress::text
                LEFT JOIN companyaddress billaddr ON billaddr.addressid = po.billtoaddress::text
                LEFT JOIN companyaddress shipaddr ON shipaddr.addressid = po.shiptoaddress::text
                LEFT JOIN termscodes tc ON tc.termscode = po.termscode
                LEFT JOIN shipviacodes svc ON svc.shipviacode = po.shipviacode
                LEFT JOIN fobcodes fc ON fc.fobcode = po.fobcode
                LEFT JOIN currencycodes cc ON cc.currencycode = po.currencycode
                LEFT JOIN taxcodes tx1 ON tx1.taxcode = pd.basetaxcode
                LEFT JOIN taxcodes tx2 ON tx2.taxcode = pd.taxcode2
                LEFT JOIN taxcodes tx3 ON tx3.taxcode = pd.taxcode3;",

            // PendingCostBOM_TTX - bom joined to partmaster TWICE (once as
            // the assembly/parent, once as the component/child) for the
            // Assembly_*/Component_* cost breakdown fields. Uses the
            // *current* cost columns (materialcost/laborcost/burdencost/
            // setupcost/subcontcost/cost), not the std* columns - matches
            // "Pending" in the report name (costs not yet rolled into
            // standard). Component_RowTotalCost/Assembly_TotalCost are
            // INFERRED: quantityper * the component's own rolled-up unit
            // cost (partmaster.cost, presumably materialcost+laborcost+
            // burdencost+setupcost+subcontcost already) - Assembly_TotalCost
            // here is just the assembly's own partmaster.cost, NOT a SUM of
            // every component row (a per-assembly rollup like that is a
            // Crystal group summary over this DataTable, not something one
            // flat SQL row can express) - if the report expects a true
            // rolled-up total instead, that needs its own summary formula
            // in the .rpt.
            ["PendingCostBOM_TTX"] = @"
                SELECT
                    b.assembly AS ""Assembly"",
                    b.component AS ""Component"",
                    b.itemsequence AS ""ItemSequence"",
                    b.quantityper AS ""QuantityPer"",
                    b.bomuomcode AS ""BOMUOMCode"",
                    b.obsoletedate AS ""ObsoleteDate"",
                    b.effectivedate AS ""EffectiveDate"",
                    am.desctext AS ""Assembly_DescText"",
                    am.revision AS ""Assembly_Revision"",
                    am.stockuom AS ""Assembly_StockUOM"",
                    am.materialcost AS ""Assembly_MaterialCost"",
                    am.laborcost AS ""Assembly_LaborCost"",
                    am.burdencost AS ""Assembly_BurdenCost"",
                    am.setupcost AS ""Assembly_SetUpCost"",
                    am.subcontcost AS ""Assembly_SubContCost"",
                    am.isc AS ""Assembly_ISC"",
                    am.orderquantity AS ""Assembly_OrderQuantity"",
                    cm.desctext AS ""Component_DescText"",
                    cm.revision AS ""Component_Revision"",
                    cm.stockuom AS ""Component_StockUOM"",
                    cm.isc AS ""Component_ISC"",
                    cm.materialcost AS ""Component_MaterialCost"",
                    cm.laborcost AS ""Component_LaborCost"",
                    cm.burdencost AS ""Component_BurdenCost"",
                    cm.setupcost AS ""Component_SetUpCost"",
                    cm.subcontcost AS ""Component_SubContCost"",
                    cm.orderquantity AS ""Component_OrderQuantity"",
                    (b.quantityper * cm.cost) AS ""Component_RowTotalCost"", -- INFERRED
                    am.cost AS ""Assembly_TotalCost"" -- INFERRED: assembly's own rolled-up cost, not a SUM of component rows
                FROM bom b
                LEFT JOIN partmaster am ON am.partnumber = b.assembly
                LEFT JOIN partmaster cm ON cm.partnumber = b.component;",
        };'''

new_text = text[:start] + new_block + text[end:]
open(path, "w", encoding="utf-8").write(new_text)
print("Replaced", len(old_block), "chars with", len(new_block), "chars")
