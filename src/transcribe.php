<?php
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

$region = "##AWS_REGION##";
$transcribeBucket = "##TRANSCRIBE_BUCKET##";
$result = null;
$error = null;
$jobs = [];

// List recent transcription jobs via AWS CLI
$listCmd = "aws transcribe list-transcription-jobs --region $region --max-results 10 --output json 2>&1";
$listOutput = shell_exec($listCmd);
if ($listOutput) {
    $listData = json_decode($listOutput, true);
    if (isset($listData['TranscriptionJobSummaries'])) {
        $jobs = $listData['TranscriptionJobSummaries'];
    }
}

// Start a new transcription job
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_FILES['audio']) && $_FILES['audio']['error'] === UPLOAD_ERR_OK) {
    $tmpFile = $_FILES['audio']['tmp_name'];
    $fileName = basename($_FILES['audio']['name']);
    $s3Key = "input/" . time() . "_" . $fileName;
    $jobName = "tp-job-" . time();

    // Upload audio file to S3
    $uploadCmd = "aws s3 cp $tmpFile s3://$transcribeBucket/$s3Key --region $region 2>&1";
    $uploadResult = shell_exec($uploadCmd);

    // Start transcription job
    $mediaUri = "s3://$transcribeBucket/$s3Key";
    $outputKey = "output/$jobName.json";

    $startCmd = "aws transcribe start-transcription-job " .
        "--region $region " .
        "--transcription-job-name $jobName " .
        "--language-code fr-FR " .
        "--media MediaFileUri=$mediaUri " .
        "--output-bucket-name $transcribeBucket " .
        "--output-key $outputKey " .
        "--output json 2>&1";

    $startOutput = shell_exec($startCmd);
    $startData = json_decode($startOutput, true);

    if (isset($startData['TranscriptionJob'])) {
        $result = "Job '$jobName' started successfully! Status: " . $startData['TranscriptionJob']['TranscriptionJobStatus'];
    } else {
        $error = "Error starting transcription: " . $startOutput;
    }
}

// Get transcription result
if (isset($_GET['job'])) {
    $jobName = escapeshellarg($_GET['job']);
    $getCmd = "aws transcribe get-transcription-job --region $region --transcription-job-name $jobName --output json 2>&1";
    $getOutput = shell_exec($getCmd);
    $getData = json_decode($getOutput, true);

    if (isset($getData['TranscriptionJob'])) {
        $job = $getData['TranscriptionJob'];
        if ($job['TranscriptionJobStatus'] === 'COMPLETED') {
            $transcriptUri = $job['Transcript']['TranscriptFileUri'];
            $transcriptContent = file_get_contents($transcriptUri);
            $transcriptData = json_decode($transcriptContent, true);
            $result = $transcriptData['results']['transcripts'][0]['transcript'] ?? 'No transcript available';
        } else {
            $result = "Job status: " . $job['TranscriptionJobStatus'];
        }
    } else {
        $error = "Error fetching job: " . $getOutput;
    }
}
?>

<!doctype html>
<html lang="fr">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, shrink-to-fit=no">
    <title>AWS Transcribe</title>
    <link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/4.0.0/css/bootstrap.min.css"
          integrity="sha384-Gn5384xqQ1aoWXA+058RXPxPg6fy4IWvTNh0E263XmFcJlSAwiGgFAW/dAiS6JXm" crossorigin="anonymous">
</head>
<body>
    <nav class="navbar navbar-expand-md navbar-dark bg-dark mb-4">
        <a class="navbar-brand" href="#">devopssec</a>
        <div class="collapse navbar-collapse">
            <ul class="navbar-nav mr-auto">
                <li class="nav-item"><a class="nav-link" href="index.php">Accueil</a></li>
                <li class="nav-item active"><a class="nav-link" href="#">Transcribe <span class="sr-only">(current)</span></a></li>
            </ul>
        </div>
    </nav>

    <main role="main" class="container">
        <h1 class="mt-5">AWS Transcribe (machine <?= gethostname() ?>)</h1>
        <hr>

        <?php if ($result): ?>
            <div class="alert alert-success"><?= htmlspecialchars($result) ?></div>
        <?php endif; ?>
        <?php if ($error): ?>
            <div class="alert alert-danger"><?= htmlspecialchars($error) ?></div>
        <?php endif; ?>

        <h2 class="mt-4 mb-3">Upload an audio file for transcription</h2>
        <form action="transcribe.php" method="post" enctype="multipart/form-data">
            <div class="form-group">
                <label for="audio">Audio file (mp3, wav, flac, ogg)</label>
                <input type="file" class="form-control-file" id="audio" name="audio" accept=".mp3,.wav,.flac,.ogg" required>
            </div>
            <button type="submit" class="btn btn-primary">Start Transcription</button>
        </form>

        <hr>
        <h2 class="mt-4 mb-3">Recent Transcription Jobs</h2>
        <?php if (empty($jobs)): ?>
            <p class="text-muted">No transcription jobs found.</p>
        <?php else: ?>
            <table class="table table-striped">
                <thead>
                    <tr>
                        <th>Job Name</th>
                        <th>Status</th>
                        <th>Language</th>
                        <th>Created</th>
                        <th>Action</th>
                    </tr>
                </thead>
                <tbody>
                <?php foreach ($jobs as $job): ?>
                    <tr>
                        <td><?= htmlspecialchars($job['TranscriptionJobName']) ?></td>
                        <td>
                            <span class="badge badge-<?= $job['TranscriptionJobStatus'] === 'COMPLETED' ? 'success' : ($job['TranscriptionJobStatus'] === 'FAILED' ? 'danger' : 'warning') ?>">
                                <?= htmlspecialchars($job['TranscriptionJobStatus']) ?>
                            </span>
                        </td>
                        <td><?= htmlspecialchars($job['LanguageCode'] ?? 'N/A') ?></td>
                        <td><?= date("d/m/Y H:i", strtotime($job['CreationTime'])) ?></td>
                        <td>
                            <?php if ($job['TranscriptionJobStatus'] === 'COMPLETED'): ?>
                                <a href="?job=<?= urlencode($job['TranscriptionJobName']) ?>" class="btn btn-sm btn-info">View Result</a>
                            <?php else: ?>
                                <a href="?job=<?= urlencode($job['TranscriptionJobName']) ?>" class="btn btn-sm btn-secondary">Check Status</a>
                            <?php endif; ?>
                        </td>
                    </tr>
                <?php endforeach; ?>
                </tbody>
            </table>
        <?php endif; ?>
    </main>

    <footer class="page-footer font-small bg-dark mt-5">
        <div class="footer-copyright text-center py-3 text-white">&copy; Copyright: <a href="#">Mon App</a></div>
    </footer>
</body>
</html>
