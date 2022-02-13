import zipfile
import dimspy.tools as ts
import os
import shutil
import json
import numpy
import sys
import galaxy

def process_samples_locally(workflow_config):
    data_path = workflow_config.get('data_path')
    filelist_filename = workflow_config.get('filelist_path')
    output_directory = workflow_config.get('output_directory')
    scans_path = workflow_config.get('scans_path')
    use_scans_path = workflow_config.get('use_scans_path', False)

    print('Process scans...')

    if use_scans_path and os.path.exists(scans_path):
        scans = ts.hdf5_portal.load_peaklists_from_hdf5(scans_path)
    else:
        data_directory = data_path

        if zipfile.is_zipfile(data_path):
            with zipfile.ZipFile(data_path, 'r') as zip_ref:
                data_directory = 'data'
                zip_ref.extractall(data_directory)

        process_scans_opt = workflow_config.get('process_scans')
        scans = ts.process_scans(
            data_directory,
            function_noise=process_scans_opt.get('function_noise'),
            snr_thres=process_scans_opt.get('snr_thres'),
            ppm=process_scans_opt.get('ppm'),
            min_fraction=process_scans_opt.get('min_fraction'),
            min_scans=process_scans_opt.get('min_scans'),
            filelist=filelist_filename)

        if scans_path is not None:
            ts.hdf5_portal.save_peaklists_as_hdf5(scans, scans_path)

    print('Applying replicate filter...')
    replicate_filter_opt = workflow_config.get('replicate_filter')
    filtered_scans = ts.replicate_filter(
        scans,
        replicates=replicate_filter_opt.get('replicates'),
        min_peaks=replicate_filter_opt.get('min_peaks'),
        ppm=replicate_filter_opt.get('ppm'),
        rsd_thres=replicate_filter_opt.get('rsd_thres'),
        report=os.path.join(output_directory, 'processing_report.tsv'))
    ts.create_sample_list(filtered_scans, os.path.join(output_directory, 'meta_filtered-scans.tsv'))

    print('Aligning samples...')
    align_samples_opt = workflow_config.get('align_samples')
    peak_matrix = ts.align_samples(
        filtered_scans,
        ppm=align_samples_opt.get('ppm'),
        filelist=os.path.join(output_directory, 'meta_filtered-scans.tsv'))

    print('Applying blank filter...')
    blank_filter_opt = workflow_config.get('blank_filter')
    peak_matrix_blank_filtered = ts.blank_filter(
        peak_matrix,
        blank_label=blank_filter_opt.get('label'),
        min_fold_change=blank_filter_opt.get('min_fold_change'),
        min_fraction=blank_filter_opt.get('min_fraction'),
        function=blank_filter_opt.get('function'))
    ts.create_sample_list(peak_matrix_blank_filtered, os.path.join(output_directory, 'peak-intensity-matrix_meta.tsv'))

    print('Applying sample filter...')
    sample_filter_opt = workflow_config.get('sample_filter')
    peak_matrix_filtered = ts.sample_filter(
        peak_matrix_blank_filtered,
        min_fraction=sample_filter_opt.get('min_fraction'))

    numpy.savetxt(os.path.join(output_directory, 'rsd.tsv'), peak_matrix_filtered.rsd(classLabel = workflow_config.get('qc_label')), delimiter = '\t')

    pim_h5_tmp = os.path.join(output_directory, 'peak-intensity-matrix.h5')

    ts.hdf5_portal.save_peak_matrix_as_hdf5(
        peak_matrix_filtered,
        pim_h5_tmp
    )
    ts.hdf5_peak_matrix_to_txt(
        pim_h5_tmp,
        os.path.join(output_directory, 'peak-intensity-matrix.tsv')
    )
    ts.hdf5_peak_matrix_to_txt(
        pim_h5_tmp,
        os.path.join(output_directory, 'peak-intensity-matrix_comprehensive.tsv'),
        comprehensive=True
    )

    os.remove(pim_h5_tmp)

def process_samples(config_filename):
    workflow_config_fd = open(config_filename)
    workflow_config = json.load(workflow_config_fd)
    workflow_config_fd.close()

    output_directory = workflow_config.get('output_directory')
    galaxy_opts = workflow_config.get('galaxy')

    if os.path.isdir(output_directory):
        shutil.rmtree(output_directory)
    os.mkdir(output_directory)

    shutil.copyfile(config_filename, os.path.join(output_directory, 'workflow-configuration.json'))

    if galaxy_opts is not None and galaxy_opts.get('enabled'):
        galaxy.run_workflow(workflow_config)
    else:
        process_samples_locally(workflow_config)
