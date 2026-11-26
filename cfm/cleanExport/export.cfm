<cfscript>

/*************** CONFIG ***************/
dsn        = "BRANCH_Directory";
inFile     = expandPath("importData.xlsx");
outFile    = expandPath("LPRAB - Timekeeping Report Q4 2025-26-CLEAN.xlsx");
sheetName  = "Data";
/****************************************/


/*************** 1) LOAD MAPPING FROM DB ***************/
getMapQuery = "
    SELECT DISTINCT fullName, DirectorateNameE
    FROM BRANCH_Directory.dbo.vUserInfo
    WHERE DirectorateNameE IS NOT NULL
";
mapQ = queryExecute(getMapQuery, [], {datasource = dsn});

map = {};
if (mapQ.recordCount > 0) {
    for (i = 1; i <= mapQ.recordCount; i++) {
        key = trim(mapQ.fullName[i]);
        if (len(key)) {
            map[key] = mapQ.DirectorateNameE[i];
        }
    }
}


/*************** 2) READ SPREADSHEET SAFELY ***************/
if (!fileExists(inFile)) {
    writeOutput("ERROR: File not found: " & inFile); abort;
}

try {
    cfspreadsheet(action="read", src=inFile, query="dataQ", headerrow=1, sheetname=sheetName);
} catch (any e1) {
    try {
        cfspreadsheet(action="read", src=inFile, query="dataQ", headerrow=1, sheet=1);
    } catch (any e2) {
        try {
            cfspreadsheet(action="read", src=inFile, query="dataQ", headerrow=1);
        } catch (any e3) {
            writeOutput("ERROR LOADING XLSX<br>");
            writeOutput(e1.message & "<br>" & e2.message & "<br>" & e3.message);
            abort;
        }
    }
}

if (!isQuery(dataQ)) {
    writeOutput("ERROR: Spreadsheet not loaded."); abort;
}


/*************** 3) FIND CONTACT COLUMN ***************/
columns = listToArray(dataQ.columnList, ",");
contactCol = "";

for (i=1; i<=arrayLen(columns); i++) {
    if (findNoCase("contact", columns[i])) {
        contactCol = columns[i];
        break;
    }
}

if (contactCol == "") {
    writeOutput("ERROR: No contact column found. Got: " & dataQ.columnList);
    abort;
}


/*************** 4) ADD DIRECTORATE COLUMN ***************/
blankArr = arrayNew(1);
for (i=1; i<=dataQ.recordCount; i++) { arrayAppend(blankArr, ""); }

QueryAddColumn(dataQ, "Directorate", blankArr);


/*************** PARSE CONTACT NAMES FUNCTION ***************/
function parseContactCell(contactCell) {
    var arr = [];
    if (!len(trim(contactCell))) return arr;

    var normalized = reReplace(contactCell, "[\r\n]+", chr(10), "all");
    var lines = listToArray(normalized, chr(10));

    for (var j=1; j<=arrayLen(lines); j++) {
        var line = trim(lines[j]);
        if (!len(line)) continue;

        var pos = find("[", line);
        if (pos) line = trim(left(line, pos-1));

        if (find(",", line)) {
            parts = listToArray(line, ",");
            if (arrayLen(parts) >= 2) {
                fullname = trim(parts[2]) & " " & trim(parts[1]);
            } else fullname = trim(line);
        } else fullname = trim(line);

        if (len(fullname)) arrayAppend(arr, fullname);
    }

    return arr;
}


/*************** 5) FILL DIRECTORATE VALUES ***************/
for (r=1; r<=dataQ.recordCount; r++) {
    namesArr = parseContactCell(dataQ[contactCol][r]);
    dset = {};

    for (k=1; k<=arrayLen(namesArr); k++) {
        nm = namesArr[k];

        if (structKeyExists(map, nm)) {
            dset[ map[nm] ] = true;
        } else {
            for (mi=1; mi<=mapQ.recordCount; mi++) {
                if (compareNoCase(mapQ.fullName[mi], nm) == 0) {
                    dset[ mapQ.DirectorateNameE[mi] ] = true;
                    break;
                }
            }
        }
    }

    dlist = [];
    for (dk in dset) arrayAppend(dlist, dk);

    result = arrayLen(dlist) ? arrayToList(dlist, ", ") : "Not found";

    QuerySetCell(dataQ, "Directorate", result, r);
}


/*************** 6) REORDER COLUMNS (DIRECTORATE RIGHT AFTER CONTACT) ***************/
origCols = listToArray(dataQ.columnList, ",");
desiredCols = [];
inserted = false;

for (i=1; i<=arrayLen(origCols); i++) {
    arrayAppend(desiredCols, origCols[i]);
    if (compareNoCase(origCols[i], contactCol)==0 && !inserted) {
        arrayAppend(desiredCols, "Directorate");
        inserted = true;
    }
}
if (!inserted) arrayAppend(desiredCols, "Directorate");


/*************** 7) SANITIZE COLUMN NAMES ***************/
safeCols = [];
displayCols = [];
safeUsed = {};

for (i=1; i<=arrayLen(desiredCols); i++) {
    display = desiredCols[i];
    safe = reReplace(display, "[^A-Za-z0-9_]", "_", "all");
    safe = reReplace(safe, "_{2,}", "_", "all");

    if (len(safe)==0 OR !reFind("^[A-Za-z]", safe)) safe = "C_" & safe;

    base = safe; sfx = 1;
    while (structKeyExists(safeUsed, safe)) { safe = base & "_" & sfx; sfx++; }
    safeUsed[safe] = true;

    arrayAppend(safeCols, safe);
    arrayAppend(displayCols, display);
}


/*************** 8) BUILD OUTQ WITH CLEAN COLUMNS ***************/
outQ = queryNew("");

rowCount = dataQ.recordCount;

for (i=1; i<=arrayLen(safeCols); i++) {
    blankArr = arrayNew(1);
    for (r=1; r<=rowCount; r++) arrayAppend(blankArr, "");
    QueryAddColumn(outQ, safeCols[i], blankArr);
}


/*************** 9) COPY VALUES FROM dataQ → outQ ***************/
for (r=1; r<=rowCount; r++) {
    for (i=1; i<=arrayLen(safeCols); i++) {
        sCol = safeCols[i];
        orig = displayCols[i];

        if (compareNoCase(orig, "Directorate")==0) {
            val = dataQ.Directorate[r];
        } else {
            val = "";
            if (listFindNoCase(dataQ.columnList, orig))
                val = dataQ[orig][r];
            else {
                alt = reReplace(orig, "[^A-Za-z0-9_]", "_", "all");
                alt = reReplace(alt, "_{2,}", "_", "all");
                if (listFindNoCase(dataQ.columnList, alt))
                    val = dataQ[alt][r];
            }
        }

        QuerySetCell(outQ, sCol, val, r);
    }
}

dataQ = outQ;


/*************** 10) WRITE XLSX SAFELY ***************/
if (ReFind("[\\/]", outFile)) {
    lastSlash = ReFind("[\\/](?!.*[\\/])", outFile);
    outDir = Left(outFile, lastSlash-1);
} else outDir = "";

if (len(outDir) && !directoryExists(outDir)) {
    writeOutput("ERROR: Output directory not found: " & outDir);
    abort;
}

try {
    cfspreadsheet(action="write", filename=outFile, query="dataQ", sheetname=sheetName, overwrite=true);
    writeOutput("SUCCESS using sheetname()");
} catch (any e1) {
    try {
        cfspreadsheet(action="write", filename=outFile, query="dataQ", sheet=1, overwrite=true);
        writeOutput("SUCCESS using sheet=1");
    } catch (any e2) {
        cfspreadsheet(action="write", filename=outFile, query="dataQ", overwrite=true);
        writeOutput("SUCCESS using default sheet");
    }
}

writeOutput("<br>Completed. File saved: " & outFile);

</cfscript>