
const String OUT_DIR = "MyData/";
const String ASSET_DIR = "Asset/";
const String MODEL_ARGS = " -t na -l -cm -ct";
const String ANIMATION_ARGS = " -nm -nt";
const bool showOutput = false;
String exportFolder;

void ExecuteCmd(const String&in cmd)
{
    Print("[CMD] " + cmd);
    String osCmd = cmd;
    if (GetPlatform() == "Windows")
    {
        osCmd.Replace("/", "\\");
    }
    fileSystem.SystemCommand(osCmd, showOutput);
}

void PreProcess()
{
    Array<String>@ arguments = GetArguments();
    for (uint i=0; i<arguments.length; ++i)
    {
        if (arguments[i] == "-folder")
        {
            exportFolder = arguments[i + 1];
        }
    }

    Print("exportFolder=" + exportFolder);
    fileSystem.CreateDir(OUT_DIR + "Models");
    fileSystem.CreateDir(OUT_DIR + "Animations");
}

String DoProcess(const String&in name, const String&in folderName, const String&in args, bool checkFolders)
{
    if (!exportFolder.empty && checkFolders)
    {
        if (!name.Contains(exportFolder))
            return "";
    }

    String iname = folderName + name;
    uint pos = name.FindLast('.');
    String oname = OUT_DIR + folderName + name.Substring(0, pos) + ".mdl";
    pos = oname.FindLast('/');
    String outFolder = oname.Substring(0, pos);
    fileSystem.CreateDir(outFolder);
    ExecuteCmd("tool/AssetImporter model Asset/" + iname + " " + oname + args);
    return oname;
}

void ProcessModels()
{
    Array<String> models = fileSystem.ScanDir(ASSET_DIR + "Models", "*.*", SCAN_FILES, true);
    for (uint i=0; i<models.length; ++i)
    {
        Print("Found a model " + models[i]);
        DoProcess(models[i], "Models/", MODEL_ARGS, false);
    }
}

void ProcessAnimations()
{
    Array<String> animations = fileSystem.ScanDir(ASSET_DIR + "Animations", "*.*", SCAN_FILES, true);
    for (uint i=0; i<animations.length; ++i)
    {
        Print("Found a animation " + animations[i]);
        String outMdlName = DoProcess(animations[i], "Animations/", ANIMATION_ARGS, true);
        if (!outMdlName.empty)
            fileSystem.Delete(outMdlName);
    }
}

void PostProcess()
{

}

void Start()
{
    uint startTime = time.systemTime;
    PreProcess();
    ProcessModels();
    ProcessAnimations();
    PostProcess();
    Print("\n\n BATCH PROCESS TIME COST = " + String(time.systemTime - startTime) + " ms");
    engine.Exit();
}