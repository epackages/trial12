import std.process;
import std.stdio;
import std.algorithm;
import std.getopt;
import std.file;
import std.array;
import std.path;
import std.conv;
import std.string;
import core.time;
import core.thread;

import dub.internal.vibecompat.data.json;

import dub.commandline;
import dub.compilers.compiler;
import dub.dependency;
import dub.dub;
import dub.generators.generator;
import dub.internal.vibecompat.core.file;
import dub.internal.vibecompat.core.log;
import dub.internal.vibecompat.data.json;
import dub.internal.vibecompat.inet.url;
import dub.package_;
import dub.packagemanager;
import dub.packagesuppliers;
import dub.platform;
import dub.project;
import dub.description;
import dub.internal.utils;

import trial.generator;
import trial.settings;
import trial.coverage;
import trial.command;
import trial.description;
import trial.runnersettings;

auto parseGeneralOptions(string[] args, bool isSilent) {
  CommonOptions options;

  LogLevel loglevel = LogLevel.info;
  options.root_path = getcwd();

  auto common_args = new CommandArgs(args);
  options.prepare(common_args);

  if (options.vverbose) loglevel = LogLevel.debug_;
  else if (options.verbose) loglevel = LogLevel.diagnostic;
  else if (options.vquiet) loglevel = LogLevel.none;
  else if (options.quiet) loglevel = LogLevel.warn;

  setLogLevel(isSilent ? LogLevel.none : loglevel);

  return options;
}

private void writeOptions(CommandArgs args)
{
  foreach (arg; args.recognizedArgs) {
    auto names = arg.names.split("|").map!(a => a.length == 1 ? "-" ~ a : "--" ~ a).array;

    writeln("  ", names.join(" "));
    writeln(arg.helpText.map!(a => "     " ~ a).join("\n"));
    writeln;
  }
}

private void showHelp(in TrialCommand command, CommandArgs common_args)
{
  writeln(`USAGE: trial [--version] [subPackage] [<options...>]

Run the tests using the trial runner. It will parse your source files and it will
generate the "trial_package.d" file. This file contains a custom main function that will
discover and execute your tests.

Available options
==================`);
  writeln();
  writeOptions(common_args);
  writeln();

  showVersion();
}

void showVersion() {
  import trial.version_;
  writefln("Trial %s, based on DUB version %s, built on %s", trialVersion, getDUBVersion(), __DATE__);
}

version(unitttest) {} else {
  int main(string[] arguments) {
    import trial.runner;
    setupSegmentationHandler!false;

    arguments = arguments.map!(a => a.strip).filter!(a => a != "").array;

    version(Windows) {
      environment["TEMP"] = environment["TEMP"].replace("/", "\\");
    }

    arguments = arguments[1..$];

    if(arguments.length > 0 && arguments[0] == "--version") {
      showVersion();
      return 0;
    }

    TrialCommand cmd;
    bool silent;

    if(arguments.length > 0 && arguments[0] == "subpackages") {
      silent = true;
      cmd = new TrialSubpackagesCommand;
      arguments = [];
    } else if(arguments.length > 0 && arguments[0] == "describe") {
      silent = true;
      cmd = new TrialDescribeCommand;
      arguments = arguments[1..$];
    } else {
      cmd = new TrialCommand;
    }

    auto subPackage = arguments.find!(a => a[0] == ':');
    auto subPackageName = subPackage.empty ? "" : subPackage.front;

    auto options = parseGeneralOptions(arguments, silent);
    auto commandArgs = new CommandArgs(arguments);
    auto runnerSettings = new RunnerSettings;
    runnerSettings.applyArguments(commandArgs);

    cmd.runnerSettings = runnerSettings;
    cmd.prepare(commandArgs);

    if (options.help) {
      showHelp(cmd, commandArgs);
      return 0;
    }

    auto description = new PackageDescriptionCommand(options, subPackageName);
    auto packageName = subPackage.empty ? [] : [ subPackage.front ];
    auto project = new TrialProject(description, runnerSettings);
    description.runnerSettings = runnerSettings;

    /// run the trial command
    cmd.setProject(project);
    auto remainingArgs = commandArgs
      .extractRemainingArgs()
      .filter!`a != "-v"`
      .filter!`a != "--verbose"`
      .filter!`a != "--vverbose"`
      .array;

    if (remainingArgs.any!(a => a.startsWith("-"))) {
      logError("Unknown command line flags: %s", remainingArgs.filter!(a => a.startsWith("-")).array.join(" "));
      return 1;
    }

    logDiagnostic("Creating the dub object");
    auto dub = createDub(options);

    try {
      logDiagnostic("execute command");
      cmd.execute(dub, remainingArgs);
    } catch(Exception e) {
      stderr.writeln(e.msg);
      logDiagnostic("failed to execute");
      return 1;
    } finally {
      if(arguments.canFind("--coverage")) {
        string source = buildPath("coverage", "raw");
        string destination = buildPath(runnerSettings.settings.artifactsLocation, "coverage");
        logDiagnostic("calculate the code coverage");

        writeln("Line coverage: ",
          convertLstFiles(source, destination, dub.rootPath.toString, dub.projectName), "%");
      }
    }

    logDiagnostic("done");
    return 0;
  }
}
