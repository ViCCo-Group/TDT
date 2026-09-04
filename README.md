# The Decoding Toolbox (TDT)

TDT is a MATLAB toolbox for multivariate analysis of functional and structural MRI data. It supports searchlight, region-of-interest, and whole-brain analyses, together with classification, regression, representational similarity analysis, feature selection, and parameter selection.

The current stable version is **3.999K**. Download the ready-to-use ZIP from the [latest GitHub release](https://github.com/ViCCo-Group/TDT/releases/latest). The default `main` branch tracks stable releases; ongoing development is kept on the `develop` branch.

## Requirements

- MATLAB 7.3 or later. Version 3.999K was release-tested with MATLAB R2021b.
- SPM or AFNI for reading and writing brain images. TDT 3.999K adds tested SPM25 support. It also includes forward-compatible SPM26 dispatch adapters, but SPM26 was not available for direct release testing.
- A working MEX build of LIBSVM or LIBLINEAR when using those classifiers. Precompiled builds are included for several platforms; see [README.txt](decoding_toolbox/README.txt) if recompilation is necessary.

## Installation

1. Download and extract the [latest release ZIP](https://github.com/ViCCo-Group/TDT/releases/latest).
2. Add the extracted `decoding_toolbox` directory to the MATLAB path.
3. Add SPM or AFNI to the MATLAB path if you will work with brain-image files.

```matlab
addpath('/path/to/tdt_3.999K/decoding_toolbox')
cfg = decoding_defaults;
```

Calling `decoding_defaults` adds the TDT subdirectories automatically.

## Getting started

For a standard SPM analysis, start with:

```matlab
help decoding_example
```

AFNI users can start with `help decoding_example_afni`. For an editable walkthrough, open `decoding_tutorial.m`; reusable scripts are in [`templates`](decoding_toolbox/templates), and complete examples are in [`demos`](decoding_toolbox/demos).

The project website provides background, datasets, and additional documentation: [TDT – The Decoding Toolbox](https://sites.google.com/site/tdtdecodingtoolbox/).

## Citation

If you use TDT, please cite:

> Hebart, M. N., Görgen, K., & Haynes, J.-D. (2015). The Decoding Toolbox (TDT): A versatile software package for multivariate analyses of functional imaging data. *Frontiers in Neuroinformatics, 8*, 88. https://doi.org/10.3389/fninf.2014.00088

## Support and bug reports

- Ask usage questions on [Neurostars](https://neurostars.org/) with the `tdt` tag.
- Report reproducible bugs through [GitHub Issues](https://github.com/ViCCo-Group/TDT/issues).
- Review release changes in [LOG.txt](decoding_toolbox/LOG.txt).

Please include the TDT version, MATLAB version, image software/version, relevant configuration, and the complete error message in bug reports.

## License

TDT is distributed under the GNU General Public License; see [LICENSE.txt](decoding_toolbox/LICENSE.txt) and [GPLv2.0.txt](decoding_toolbox/GPLv2.0.txt). Bundled third-party components retain their own licenses, documented in `LICENSE.txt` and their source directories.
