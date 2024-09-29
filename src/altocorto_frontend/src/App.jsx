import { altocorto_backend } from 'declarations/altocorto_backend';
import React, { useState } from 'react';
import { createTheme, ThemeProvider } from '@mui/material/styles';
import Container from '@mui/material/Container';
import CssBaseline from '@mui/material/CssBaseline';
import TextField from '@mui/material/TextField';
import Button from '@mui/material/Button';
import Typography from '@mui/material/Typography';
import Box from '@mui/material/Box';
import CircularProgress from '@mui/material/CircularProgress';
import InputAdornment from '@mui/material/InputAdornment';
import IconButton from '@mui/material/IconButton';
import SearchIcon from '@mui/icons-material/Search';
import LinearProgress from '@mui/material/LinearProgress';
import { createClient } from "@connect2ic/core"
import { InternetIdentity, PlugWallet, NFID } from "@connect2ic/core/providers"
import { Connect2ICProvider, useConnect } from "@connect2ic/react"


const theme = createTheme({
  palette: {
    mode: 'dark',
    background: {
      default: '#121212',
    },
    primary: {
      main: '#90caf9',
    },
    secondary: {
      main: '#f48fb1',
    },
  },
});

// const network =
//   process.env.DFX_NETWORK ||
//   (process.env.NODE_ENV === "production" ? "ic" : "local");

// const internetIdentityUrl =
//   network === "local"
//     ? "http://localhost:4943/?canisterId=rdmx6-jaaaa-aaaaa-aaadq-cai"
//     : "https://identity.ic0.app";

// const client = createClient({
//   canisters: {
//     altocorto_backend,
//   },
//   providers: [
//     new InternetIdentity({
//       dev: true,
//       providerUrl: internetIdentityUrl,
//     }),
//     // new PlugWallet(),
//     new NFID(),
//   ],
//   globalProviderConfig: {
//     dev: true,
//   },
// });

function App() {
  const [fileUrl, setFileUrl] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [fileName, setFileName] = useState(null);
  const [videoTitle, setVideoTitle] = useState("");
  const [uploadProgress, setUploadProgress] = useState(0);


  async function handleSubmit(event) {
    event.preventDefault();
    setLoading(true);
    setError('');
    const file = event.target.elements.file.files[0];
    const fileName = file.name;
    const totalLength = file.size;
    console.log(totalLength);

    const controller = new AbortController();
    const signal = controller.signal;
    const timeoutId = setTimeout(() => controller.abort(), 700000);
    try {
      let response = await altocorto_backend.uploadRequestNonUserFoTest(fileName, totalLength);
      clearTimeout(timeoutId);

      let { tempId, chunksQty, chunkSize } = response.Ok;
      const promises = [];

      for (let i = 0; i < Number(chunksQty); i++) {
        let start = i * Number(chunkSize);
        const chunk = file.slice(start, start + Number(chunkSize));

        const arrayBuffer = await chunk.arrayBuffer();
        const uint8Array = new Uint8Array(arrayBuffer);
        console.log("Subiendo ", uint8Array.length, " Bytes from Chunck Nro ", i);
        promises.push(await altocorto_backend.addChunk(tempId, uint8Array, i));
        setUploadProgress(((i + 1) / Number(chunksQty)) * 100);
      }
      // await Promise.all(promises);
      const result = await altocorto_backend.commiUpload(tempId);
      clearTimeout(timeoutId);
      alert("Video subido exitosamente. VideoId:  " + result.Ok.toString())
    } catch (err) {
      setError('Error uploading file. Please try again.');
      console.error(err);
    } finally {
      setLoading(false);
    }
  }

  async function handleDownload(event) {
    event.preventDefault();
    setLoading(true);
    setError('');
    const { id } = event.target.elements;
    const videoId = id.value;

    try {
      const fileResponse = await altocorto_backend.startPlay(BigInt(videoId));
      if (fileResponse.Ok) {
        const video = fileResponse.Ok;
        const chunksQty = Number(video.chunksQty);
        const promises = [];

        for (let i = 0; i < chunksQty; i++) {
          console.log("Descargando chunk Nro ", i);
          promises.push(await altocorto_backend.getChunk(BigInt(videoId), BigInt(i)));
        }

        // const chunkResponses = await Promise.all(promises);
        const chunks = promises.map(response => response.Ok);

        const arrayBuffers = chunks.map(chunk => chunk.buffer);
        const combinedArrayBuffer = new Uint8Array(arrayBuffers.reduce((acc, buffer) => {
          const newBuffer = new Uint8Array(acc.length + buffer.byteLength);
          newBuffer.set(acc, 0);
          newBuffer.set(new Uint8Array(buffer), acc.length);
          return newBuffer;
        }, new Uint8Array()));

        const blob = new Blob([combinedArrayBuffer], { type: 'application/octet-stream' });
        const url = URL.createObjectURL(blob);
        setFileUrl(url);
        setVideoTitle(video.title);

        return () => {
          URL.revokeObjectURL(url);
        };
      } else {
        throw new Error('Error downloading file');
      }
    } catch (err) {
      setError('Error downloading file. Please try again.');
      console.error(err);
    } finally {
      setLoading(false);
    }
  }

  return (
    <ThemeProvider theme={theme}>
      <CssBaseline />
      <Container maxWidth="100%">
        <Box sx={{ mt: 4, mb: 4, textAlign: 'center' }}>
          <Typography variant="h5" component="h1" gutterBottom>
            Alto Corto Plataforma
          </Typography>
          <p>ICP Hub Argentina Hackathon Septiembre 2024</p>

          {/* Formulario para subir archivos */}
          <form onSubmit={handleSubmit} style={{ marginBottom: '20px', padding: '10px', width: "100%", maxWidth: "500px", minWidth: "250px" }}>
            <input
              type="file"
              id="file"
              name="file"
              placeholder="Select file"
              required
              style={{ display: 'none' }}
              onChange={(e) => setFileName(e.target.files[0]?.name)}
            />
            <label htmlFor="file" style={{borderRadius: '30px', width: "100%", maxWidth: "500px", minWidth: "250px" }}>
              <Button
                variant="contained"
                color="primary"
                component="span"
                style={{ width: "100%", fontSize: '0.7rem' }}
              >
                {fileName || 'Seleccionar archivo'}
              </Button>
            </label>

            <Button
              type="submit"
              variant="contained"
              color="primary"
              disabled={loading}
              style={{ width: "90vw", fontSize: '0.7rem' }}
            >
              SUBIR
            </Button>
          </form>
          {loading && (
            <Box sx={{ display: 'flex', flexDirection: 'column', alignItems: 'center', marginBottom: '20px', width: '100%' }}>
              <LinearProgress variant="determinate" value={uploadProgress} sx={{ width: '80%', marginBottom: '10px' }} />
              <Typography variant="body2" color="textSecondary">{Math.round(uploadProgress)}%</Typography>
            </Box>
          )}

          {/* Formulario para buscar por ID */}
          <form onSubmit={handleDownload} style={{borderRadius: '30px', width: "100%", maxWidth: "500px", minWidth: "250px" }}>
            <TextField
              name="id"
              variant="outlined"
              fullWidth
              required
              margin="normal"
              placeholder="Enter Video ID"
              InputProps={{
                endAdornment: (
                  <InputAdornment position="end" >
                    <IconButton style={{ textAlign: "center"}}
                      aria-label="search"
                      type="submit"
                      edge="end"
                      disabled={loading}
                      sx={{
                        color: '#aaa',
                        backgroundColor: 'transparent',
                        '&:hover': { backgroundColor: 'transparent' },
                        '&:active': { backgroundColor: 'transparent' },
                      }}
                    >
                      <SearchIcon />
                    </IconButton>
                  </InputAdornment>
                ),
                style: {
                  borderRadius: '30px', // Bordes completamente redondeados
                  // padding: '4px 0px 4px 0px',
                  padding: "0"
                },
              }}
              style={{ marginTop: '0px', marginBottom: '0px' }} // Reducir margen vertical
            />
          </form>

          {loading && (
            <Box sx={{ display: 'flex', justifyContent: 'center', marginBottom: '20px' }}>
              <CircularProgress />
            </Box>
          )}

          {error && (
            <Typography variant="body2" color="error" gutterBottom>
              {error}
            </Typography>
          )}

          {fileUrl && (
            <>
            <p>{videoTitle}</p>
              <video controls autoPlay src={fileUrl} style={{ display: 'block', marginTop: '20px', width: "85%",  }} />
              <Button
                href={fileUrl}
                download="downloadedFile"
                variant="contained"
                color="primary"
                style={{ marginTop: '20px', fontSize: '0.7rem' }} // Ajusta el tamaño de la fuente
              >
                Download File
              </Button>
            </>
          )}
        </Box>
      </Container>
    </ThemeProvider>
  );
}

export default App;
