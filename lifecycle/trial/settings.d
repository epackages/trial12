/++
  Settings parser and structures

  Copyright: © 2017 Szabo Bogdan
  License: Subject to the terms of the MIT license, as written in the included LICENSE.txt file.
  Authors: Szabo Bogdan
+/
module trial.settings;
import std.conv;

import trial.reporters.result;
import trial.reporters.spec;
import trial.reporters.specsteps;
import trial.reporters.dotmatrix;
import trial.reporters.landing;
import trial.reporters.progress;

version (Have_fluent_asserts) {
  version = Have_fluent_asserts_core;
}

version(Have_dub) {
  import dub.internal.vibecompat.data.serialization;
}

///
mixin template SettingsFields()
{
  /*
  bool colors;
  bool sort;
  bool bail;*/

  /** The reporter list that will be added by the runner at startup
   * You can use here only the embeded reporters.
   * If you want to use a custom reporter you can use `static this` constructor
   *
   * Examples:
   * ------------------------
   * static this
   * {
   *    LifeCycleListeners.instance.add(myCustomReporter);
   * }
   * ------------------------
   */
  string[] reporters = ["spec", "result"];

  /// The test discovery classes that you want to use
  string[] testDiscovery = ["trial.discovery.unit.UnitTestDiscovery"];

  deprecated("use .executor instead") bool runInParallel = false;

  /// The number of threads tha you want to use
  /// `0` means the number of cores that your processor has
  uint maxThreads = 0;

  ///
  GlyphSettings glyphs;

  /// Where to generate artifacts
  string artifactsLocation = ".trial";

  /// Show the duration with yellow if it takes more `warningTestDuration` msecs
  uint warningTestDuration = 20;

  /// Show the duration with red if it takes more `dangerTestDuration` msecs
  uint dangerTestDuration = 100;

  /// A list of plugins that will be added as dependencies from
  /// code.dlang.org. The plugins will be imported in the main file.
  ///
  /// For `trial-my-plugin` the import will be `import trialmyplugin.plugin`.
  /// You will be able to create a module constructor that will add all your needed 
  /// lifecycle listeners.
  string[] plugins = [];

  /// The default executor is `SingleRunner`. If you want to use the
  /// `ParallelExecutor` set this option to `parallel` or if you want
  /// to use the `ProcessExecutor` set it to `process`.
  string executor = "default";
}

/// A structure representing the `trial.json` file
struct Settings
{
  version(Have_dub) {
    @optional {
      mixin SettingsFields;
    }
  } else {
    mixin SettingsFields;
  }

  this(string[] reporters, 
    string[] testDiscovery, 
    string executor, 
    int maxThreads,
    GlyphSettings glyphs,
    string artifactsLocation,
    int warningTestDuration,
    int dangerTestDuration,
    string[] plugins = []) {

      this.reporters = reporters;
      this.testDiscovery = testDiscovery;
      this.executor = executor;
      this.maxThreads = maxThreads;
      this.glyphs = glyphs;
      this.artifactsLocation = artifactsLocation;
      this.warningTestDuration = warningTestDuration;
      this.dangerTestDuration = dangerTestDuration;
      this.plugins = plugins;
  }

  this(string[] reporters, 
    string[] testDiscovery,
    bool, // deprecated
    int maxThreads,
    GlyphSettings glyphs,
    string artifactsLocation,
    int warningTestDuration,
    int dangerTestDuration,
    string[] plugins = [],
    string executor = "default") {

      this.reporters = reporters;
      this.testDiscovery = testDiscovery;
      this.executor = executor;
      this.maxThreads = maxThreads;
      this.glyphs = glyphs;
      this.artifactsLocation = artifactsLocation;
      this.warningTestDuration = warningTestDuration;
      this.dangerTestDuration = dangerTestDuration;
      this.plugins = plugins;
  }
}

mixin template GlyphSettingsFields()
{
  ///
  SpecGlyphs spec;

  ///
  SpecStepsGlyphs specSteps;

  ///
  TestResultGlyphs result;

  ///
  DotMatrixGlyphs dotMatrix;

  ///
  LandingGlyphs landing;

  ///
  ProgressGlyphs progress;
}

/// The gliph settings
struct GlyphSettings {
  version(Have_dub) {
    @optional {
      mixin GlyphSettingsFields;
    }
  } else {
    mixin GlyphSettingsFields;
  }
}

/// Converts the settings object to DLang code. It's used by the generator
string toCode(Settings settings)
{
  auto executor = settings.executor == "default" ? "" : `"` ~ settings.executor ~ `"`;

  return "Settings(" ~
    settings.reporters.to!string ~ ", " ~
    settings.testDiscovery.to!string ~ ", " ~
    `false,` ~ 
    settings.maxThreads.to!string ~ ", " ~
    settings.glyphs.toCode ~ ", " ~
    `"` ~ settings.artifactsLocation ~ `", ` ~
    settings.warningTestDuration.to!string ~ `, ` ~
    settings.dangerTestDuration.to!string ~
    executor ~
    ")";
}

/// Converts the GlyphSettings object to DLang code. It's used by the generator
string toCode(GlyphSettings settings) {
  return "GlyphSettings(" ~
      specGlyphsToCode(settings.spec) ~ ", " ~
      specStepsGlyphsToCode(settings.specSteps) ~ ", " ~
      testResultGlyphsToCode(settings.result) ~ ", " ~
      dotMatrixGlyphsToCode(settings.dotMatrix) ~ ", " ~
      landingGlyphsToCode(settings.landing) ~ ", " ~
      progressGlyphsToCode(settings.progress) ~
    ")";
}

version (unittest)
{
  version(Have_fluent_asserts_core) {
    import fluent.asserts;
  }
}

/// it should be able to compile the settings code
unittest {
  mixin("auto settings = " ~ Settings().toCode ~ ";");
}

/// it should be able to transform the Settings to code
unittest
{
	Settings settings;

	settings.toCode.should.equal(`Settings(` ~
     `["spec", "result"], ` ~
     `["trial.discovery.unit.UnitTestDiscovery"], false,0, ` ~
      "GlyphSettings(SpecGlyphs(`✓`), " ~
                    "SpecStepsGlyphs(`┌`, `└`, `│`), "~
                    "TestResultGlyphs(`✖`), " ~
                    "DotMatrixGlyphs(`.`,`!`,`?`), " ~
                    "LandingGlyphs(`✈`,`━`,`⋅`), " ~
                    "ProgressGlyphs(`░`,`▓`)" ~
      "), " ~
      `".trial", ` ~
      "20, 100"~
      `)`);
}
