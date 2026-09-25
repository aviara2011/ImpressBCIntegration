codeunit 80001 "Impress Item Processor"
{
    TableNo = "Impress Item Staging";

    trigger OnRun()
    begin
        ProcessItemStaging(Rec);
    end;

    procedure ProcessNewItems()
    var
        ImpressItemProcessingRunner: Codeunit "Impress Item Processing Runner";
    begin
        ImpressItemProcessingRunner.ProcessNewItems();
    end;

    local procedure ProcessItemStaging(var ImpressItemStaging: Record "Impress Item Staging")
    var
        Item: Record Item;
        ItemVariant: Record "Item Variant";
        ImpressDefaults: Record "Impress Defaults";
        ItemUnitOfMeasureCode: Code[10];
    begin
        ImpressItemStaging.Status := ImpressItemStaging.Status::Processing;
        ImpressItemStaging.Modify(true);

        if not Item.Get(ImpressItemStaging."Item No.") then begin
            Item.Init();
            Item.Validate("No.", ImpressItemStaging."Item No.");
            Item.Validate(Description, CopyStr(ImpressItemStaging.Description, 1, MaxStrLen(Item.Description)));
            if ImpressDefaults.Get() then begin
                if ImpressDefaults."Item Gen. Prod. Post. Group" <> '' then
                    Item.Validate("Gen. Prod. Posting Group", ImpressDefaults."Item Gen. Prod. Post. Group");
                if ImpressDefaults."Item Inventory Posting Group" <> '' then
                    Item.Validate("Inventory Posting Group", ImpressDefaults."Item Inventory Posting Group");
            end;
            if ImpressItemStaging."Unit of Measure" <> '' then
                ItemUnitOfMeasureCode := ImpressItemStaging."Unit of Measure"
            else
                if ImpressDefaults."Item Unit of Measure Code" <> '' then
                    ItemUnitOfMeasureCode := ImpressDefaults."Item Unit of Measure Code";
            if ImpressItemStaging."Item Category Code" <> '' then
                Item.Validate("Item Category Code", ImpressItemStaging."Item Category Code");
            ValidateItemVendorNoIfVendorExists(Item, ImpressItemStaging."Preferred Vendor No.");
            Item.Insert(true);

            if ItemUnitOfMeasureCode <> '' then begin
                Item.Validate("Base Unit of Measure", ItemUnitOfMeasureCode);
                Item.Modify(true);
            end;
        end else begin
            Item.Validate(Description, CopyStr(ImpressItemStaging.Description, 1, MaxStrLen(Item.Description)));
            if ImpressItemStaging."Item Category Code" <> '' then
                Item.Validate("Item Category Code", ImpressItemStaging."Item Category Code");
            ValidateItemVendorNoIfVendorExists(Item, ImpressItemStaging."Preferred Vendor No.");
            Item.Modify(true);
        end;

        if not ItemVariant.Get(ImpressItemStaging."Item No.", ImpressItemStaging."Variant Code") then begin
            ItemVariant.Init();
            ItemVariant.Validate("Item No.", ImpressItemStaging."Item No.");
            ItemVariant.Validate(Code, ImpressItemStaging."Variant Code");
            ItemVariant.Validate(Description, CopyStr(ImpressItemStaging.Description, 1, MaxStrLen(ItemVariant.Description)));
            ItemVariant.Insert(true);
        end else begin
            ItemVariant.Validate(Description, CopyStr(ImpressItemStaging.Description, 1, MaxStrLen(ItemVariant.Description)));
            ItemVariant.Modify(true);
        end;

        ImpressItemStaging.Status := ImpressItemStaging.Status::Processed;
        ImpressItemStaging."Processed DateTime" := CurrentDateTime();
        Clear(ImpressItemStaging."Error Message");
        ImpressItemStaging.Modify(true);
    end;

    local procedure ValidateItemVendorNoIfVendorExists(var Item: Record Item; VendorNo: Code[20])
    var
        Vendor: Record Vendor;
    begin
        if VendorNo = '' then
            exit;

        if Vendor.Get(VendorNo) then
            Item.Validate("Vendor No.", VendorNo);
    end;
}
