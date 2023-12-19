import React from "react";
import Layout from "@theme/Layout";

export default function hello() {
    return (
        <Layout title="hello" description="hello react page">
            <div
            style={{
                display: 'flex',
                justifyContent: 'center',
                alignItems: 'center',
                height: '50vh',
                fontSize: '20px',
            }}
            >
                <p>Edit <code>pages/helloReact.js</code> and save to reload </p>
            </div>
        </Layout>
    )
}